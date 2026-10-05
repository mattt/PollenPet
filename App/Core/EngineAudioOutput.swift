import AVFoundation

@MainActor final class EngineAudioOutput: AudioOutput {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()

    private static let volume: Float = 0.28

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
