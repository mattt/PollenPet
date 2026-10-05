import AVFoundation
import Observation

enum PlaybackState: Sendable {
    case idle, preparing, playing, paused, finished
}

@MainActor @Observable final class PlaybackController {
    private(set) var performance: Performance? {
        didSet { replyTime = performance?.replyPresentationTime ?? .infinity }
    }
    private(set) var elapsed: Double = 0 {
        didSet {
            // Publish only the crossing, so reply views don't update on every tick.
            if reachedReplyTime != (elapsed >= replyTime) { reachedReplyTime.toggle() }
        }
    }
    private(set) var reachedReplyTime = false
    private(set) var state: PlaybackState = .idle
    private(set) var audioUnavailable = false
    var isMuted = false {
        didSet { audio.isMuted = isMuted }
    }
    var isComplete: Bool { state == .finished }

    @ObservationIgnored private let clock: any PlaybackClock
    @ObservationIgnored private let audio: any AudioOutput
    @ObservationIgnored private let automaticTick: Bool
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var synthesis: Task<[Float], Error>?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var anchor: Double = 0
    @ObservationIgnored private var anchorElapsed: Double = 0
    @ObservationIgnored private var suspended = false
    @ObservationIgnored private var presentationReady = true
    @ObservationIgnored private var pendingInstant = false
    @ObservationIgnored private var replyTime = Double.infinity

    init(audio: any AudioOutput, clock: any PlaybackClock = SystemPlaybackClock(), automaticTick: Bool = true) {
        self.audio = audio
        self.clock = clock
        self.automaticTick = automaticTick
    }

    /// The speech clock at this moment. Display-synchronized drawing reads it
    /// between ticks; it never runs behind `elapsed`.
    var presentationTime: Double {
        guard state == .playing, let performance else { return elapsed }
        let fallback = anchorElapsed + max(0, clock.now - anchor)
        let audioTime = audioUnavailable ? nil : audio.elapsed
        // Some routes take a render cycle to provide sample time. Never rewind the reveal.
        return min(performance.duration, max(elapsed, audioTime ?? fallback))
    }

    func start(_ performance: Performance, instant: Bool = false) async {
        cancelWork()
        let currentGeneration = generation
        self.performance = performance
        elapsed = 0
        audioUnavailable = false
        if instant {
            if presentationReady { revealAll() }
            else { pendingInstant = true; state = .preparing }
            return
        }
        state = .preparing
        let work = Task.detached(priority: .userInitiated) {
            try VoiceRenderer.render(performance)
        }
        synthesis = work
        do {
            let samples = try await withTaskCancellationHandler {
                try await work.value
            } onCancel: {
                work.cancel()
            }
            guard generation == currentGeneration, !Task.isCancelled else { return }
            synthesis = nil
            do {
                try audio.prepare(samples: samples)
                if !suspended && presentationReady { try audio.play() }
            } catch {
                audio.stop()
                audioUnavailable = true
            }
            startClock()
        } catch {
            guard generation == currentGeneration else { return }
            synthesis = nil
            if Task.isCancelled || error is CancellationError {
                state = .idle
            } else {
                audioUnavailable = true
                startClock()
            }
        }
    }

    func tick() {
        guard state == .playing, let performance else { return }
        elapsed = presentationTime
        if elapsed >= performance.duration {
            elapsed = performance.duration
            state = .finished
            ticker?.cancel()
            ticker = nil
            audio.stop()
        }
    }

    func revealAll() {
        cancelWork()
        elapsed = performance?.duration ?? 0
        state = .finished
    }

    func stop() {
        cancelWork()
        performance = nil
        elapsed = 0
        state = .idle
    }

    func pause() {
        suspended = true
        pausePlayback()
    }

    func resume() {
        suspended = false
        resumePlayback()
    }

    /// Preparation can run while RealityKit loads, but speech must wait for a visible character.
    func setPresentationReady(_ ready: Bool) {
        presentationReady = ready
        if !ready { pausePlayback() }
        else if pendingInstant { revealAll() }
        else { resumePlayback() }
    }

    private func pausePlayback() {
        guard state == .playing else { return }
        tick()
        guard state == .playing else { return }
        anchorElapsed = elapsed
        audio.pause()
        ticker?.cancel()
        ticker = nil
        state = .paused
    }

    private func resumePlayback() {
        guard !suspended, presentationReady, state == .paused else { return }
        anchor = clock.now
        anchorElapsed = elapsed
        if !audioUnavailable {
            do { try audio.play() } catch {
                audio.stop()
                audioUnavailable = true
            }
        }
        state = .playing
        beginTicking()
    }

    /// Starts the speech clock at zero, or holds it paused until playback may begin.
    private func startClock() {
        anchor = clock.now
        anchorElapsed = 0
        state = suspended || !presentationReady ? .paused : .playing
        beginTicking()
    }

    private func beginTicking() {
        guard automaticTick, state == .playing else { return }
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                guard let self, self.state == .playing else { return }
                self.tick()
            }
        }
    }

    private func cancelWork() {
        generation += 1
        pendingInstant = false
        synthesis?.cancel()
        synthesis = nil
        ticker?.cancel()
        ticker = nil
        audio.stop()
    }
}

// MARK: - Clock

@MainActor protocol PlaybackClock: AnyObject {
    var now: TimeInterval { get }
}

@MainActor final class SystemPlaybackClock: PlaybackClock {
    var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
}

// MARK: - Audio Output

@MainActor protocol AudioOutput: AnyObject {
    var elapsed: TimeInterval? { get }
    var isMuted: Bool { get set }
    /// Schedules mono samples at `VoiceRenderer.sampleRate`.
    func prepare(samples: [Float]) throws
    func play() throws
    func pause()
    func stop()
}

@MainActor final class EngineAudioOutput: AudioOutput {
    private static let volume: Float = 0.28

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    var isMuted = false {
        didSet { player.volume = isMuted ? 0 : Self.volume }
    }

    init() {
        engine.attach(player)
        let format = AVAudioFormat(standardFormatWithSampleRate: VoiceRenderer.sampleRate, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.volume = Self.volume
    }

    var elapsed: TimeInterval? {
        guard engine.isRunning, player.isPlaying,
              let renderTime = player.lastRenderTime,
              let time = player.playerTime(forNodeTime: renderTime), time.sampleRate > 0 else { return nil }
        return max(0, Double(time.sampleTime) / time.sampleRate - player.outputPresentationLatency)
    }

    func prepare(samples: [Float]) throws {
        player.stop()
        guard let format = AVAudioFormat(standardFormatWithSampleRate: VoiceRenderer.sampleRate, channels: 1),
              let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let destination = pcm.floatChannelData?[0] else { throw AudioError.bufferAllocation }
        pcm.frameLength = pcm.frameCapacity
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress { destination.update(from: base, count: source.count) }
        }
        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
        player.scheduleBuffer(pcm)
    }

    func play() throws {
        if !engine.isRunning { try engine.start() }
        player.play()
    }

    func pause() { player.pause() }

    func stop() {
        player.stop()
        engine.pause()
    }

    private enum AudioError: Error { case bufferAllocation }
}
