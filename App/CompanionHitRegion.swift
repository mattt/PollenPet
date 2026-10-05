import AppKit
import SwiftUI

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
