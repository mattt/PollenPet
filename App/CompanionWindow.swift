import AppKit
import SwiftUI

// MARK: - Hit Regions

/// Regions are expressed in window coordinates so padding never becomes a hit target.
@MainActor protocol CompanionHitRegion: AnyObject {
    func acceptsCompanionHit(at point: NSPoint) -> Bool
}

struct CompanionShapeRegion<S: Shape>: NSViewRepresentable {
    let shape: S

    func makeNSView(context: Context) -> RegionView { RegionView() }
    func updateNSView(_ view: RegionView, context: Context) {
        view.containsPoint = { point, bounds in shape.path(in: bounds).contains(point) }
    }

    final class RegionView: NSView, CompanionHitRegion {
        var containsPoint: ((CGPoint, CGRect) -> Bool)?
        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func acceptsCompanionHit(at point: NSPoint) -> Bool {
            !isHiddenOrHasHiddenAncestor && (containsPoint?(convert(point, from: nil), bounds) ?? false)
        }
    }
}

// MARK: - Lifecycle

struct WindowLifecycle: NSViewRepresentable {
    let onAttach: @MainActor (NSWindow) -> Void
    let onPause: @MainActor () -> Void
    let onResume: @MainActor () -> Void
    let onClose: @MainActor () -> Void
    /// Handles Space while the window is key. Returns whether it used the key press.
    let onSpace: @MainActor () -> Bool

    func makeNSView(context: Context) -> LifecycleView {
        let view = LifecycleView()
        view.onAttach = onAttach
        view.onPause = onPause
        view.onResume = onResume
        view.onClose = onClose
        view.onSpace = onSpace
        return view
    }

    func updateNSView(_ nsView: LifecycleView, context: Context) {}

    static func dismantleNSView(_ view: LifecycleView, coordinator: ()) {
        view.stopObserving()
    }

    @MainActor final class LifecycleView: NSView {
        var onAttach: (@MainActor (NSWindow) -> Void)?
        var onPause: (@MainActor () -> Void)?
        var onResume: (@MainActor () -> Void)?
        var onClose: (@MainActor () -> Void)?
        var onSpace: (@MainActor () -> Bool)?
        private var observers: [(NotificationCenter, NSObjectProtocol)] = []
        private var hitTimer: Timer?
        private var eventMonitors: [Any] = []
        private weak var observedWindow: NSWindow?

        func stopObserving() {
            hitTimer?.invalidate()
            hitTimer = nil
            eventMonitors.forEach(NSEvent.removeMonitor)
            eventMonitors = []
            observedWindow?.ignoresMouseEvents = false
            observedWindow = nil
            for (center, observer) in observers { center.removeObserver(observer) }
            observers = []
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopObserving()
            guard let window else { return }
            observedWindow = window
            onAttach?(window)
            // A timer also catches silhouette changes under a stationary pointer.
            let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateMousePassthrough() }
            }
            RunLoop.main.add(timer, forMode: .common)
            hitTimer = timer
            if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: { [weak self] _ in
                self?.updateMousePassthrough()
            }) { eventMonitors.append(monitor) }
            if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { [weak self] event in
                self?.updateMousePassthrough()
                return event
            }) { eventMonitors.append(monitor) }
            if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown], handler: { [weak self] event in
                guard let self, event.window === self.window, event.charactersIgnoringModifiers == " ",
                      event.modifierFlags.isDisjoint(with: [.command, .option, .control, .shift]),
                      self.onSpace?() == true else { return event }
                return nil
            }) { eventMonitors.append(monitor) }
            // Only the companion window hosts this view; Settings keeps standard chrome.
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            // A plain window cannot become key, so it would never receive key presses
            // or respond to Close and Minimize. Add a title bar, then hide it.
            window.styleMask.insert([.titled, .closable, .miniaturizable, .fullSizeContentView])
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(button)?.isHidden = true
            }
            observe(NSWindow.willMiniaturizeNotification, center: .default, object: window) { [weak self] in self?.onPause?() }
            observe(NSWindow.didDeminiaturizeNotification, center: .default, object: window) { [weak self] in self?.onResume?() }
            observe(NSWindow.willCloseNotification, center: .default, object: window) { [weak self] in self?.onClose?() }
            observe(NSWorkspace.willSleepNotification, center: NSWorkspace.shared.notificationCenter) { [weak self] in self?.onPause?() }
            observe(NSWorkspace.didWakeNotification, center: NSWorkspace.shared.notificationCenter) { [weak self] in
                guard self?.window?.isMiniaturized == false else { return }
                self?.onResume?()
            }
        }

        private func updateMousePassthrough() {
            guard let window, window.isVisible, !window.isMiniaturized,
                  let content = window.contentView else { return }
            // Keep ownership of a mouse sequence until release, especially during window drags.
            guard NSEvent.pressedMouseButtons == 0 else { return }
            let point = window.convertPoint(fromScreen: NSEvent.mouseLocation)
            func acceptsHit(_ view: NSView) -> Bool {
                if let region = view as? CompanionHitRegion,
                   region.acceptsCompanionHit(at: point) { return true }
                return view.subviews.contains(where: acceptsHit)
            }
            window.ignoresMouseEvents = !acceptsHit(content)
        }

        private func observe(_ name: Notification.Name, center: NotificationCenter, object: AnyObject? = nil,
                             action: @escaping @MainActor @Sendable () -> Void) {
            let observer = center.addObserver(forName: name, object: object, queue: .main) { _ in
                MainActor.assumeIsolated { action() }
            }
            observers.append((center, observer))
        }
    }
}
