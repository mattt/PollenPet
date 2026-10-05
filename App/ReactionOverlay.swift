import RealityKit
import SwiftUI

/// Decorative, authored reactions drawn beside the projected head. The speech clock
/// drives every value; this view owns no timers, random state, or delayed tasks.
struct ReactionOverlay: View {
    let performance: Performance?
    let time: Double
    let active: Bool
    let reducedMotion: Bool
    /// The projected head, in this view's coordinates.
    let head: CGRect
    let scale: Double

    var body: some View {
        Canvas { context, size in
            if active, let performance {
                for cue in performance.reactions where time >= cue.start && time < cue.end {
                    let age = time - cue.start
                    var drawing = context
                    drawing.opacity = reducedMotion ? 0.9 : min(1, age / 0.09) * min(1, (cue.end - time) / 0.25)
                    // Each origin keeps the reaction's full extent inside the stage.
                    switch cue.reaction {
                    case .surprise:
                        // The stem stands left of the head, opposite the thought panel,
                        // with its top at the crown. The rays fan out away from the head.
                        place(&drawing, x: max(head.minX - 12 * scale, 56 * scale),
                              y: max(head.minY + 23 * scale, 62 * scale))
                        surprise(in: &drawing, age: age)
                    case .thought:
                        place(&drawing, x: min(head.maxX + 28 * scale, size.width - 26 * scale),
                              y: max(head.minY + 16 * scale, 32 * scale))
                        thought(in: &drawing)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func place(_ context: inout GraphicsContext, x: Double, y: Double) {
        context.translateBy(x: x, y: y)
        context.scaleBy(x: scale, y: scale)
    }

    private func surprise(in context: inout GraphicsContext, age: Double) {
        let pop = reducedMotion ? 1 : 1 + sin(min(1, age / 0.24) * .pi) * 0.2
        context.scaleBy(x: pop, y: pop)
        context.rotate(by: .degrees(12))
        let amber = AppTheme.yellow
        for index in 0..<3 {
            var ray = context
            ray.rotate(by: .degrees(Double(index) * 34 - 65))
            let path = Path(roundedRect: CGRect(x: -3, y: -48, width: 6, height: 17), cornerRadius: 3)
            ray.stroke(path, with: .color(AppTheme.ink), lineWidth: 3)
            ray.fill(path, with: .color(amber))
        }
        let stem = Path(roundedRect: CGRect(x: -4, y: -23, width: 8, height: 27), cornerRadius: 4)
        let dot = Path(ellipseIn: CGRect(x: -4.5, y: 9, width: 9, height: 9))
        for path in [stem, dot] {
            context.stroke(path, with: .color(AppTheme.ink), lineWidth: 4)
            context.fill(path, with: .color(amber))
        }
    }

    private func thought(in context: inout GraphicsContext) {
        let panel = Path(roundedRect: CGRect(x: -20, y: -28, width: 42, height: 48), cornerRadius: 12)
        context.fill(panel, with: .color(AppTheme.paper))
        context.stroke(panel, with: .color(AppTheme.ink), lineWidth: 2)
        context.draw(Text("?").font(AppTypography.heading(34)).foregroundStyle(AppTheme.ink), at: CGPoint(x: 1, y: -5))
    }
}

// MARK: - Hosting View

/// Draws reactions above the stage and lets mouse events reach the ARView beneath.
final class ReactionHostingView: NSHostingView<ReactionOverlay> {
    func projectedAnchor(_ position: SIMD3<Float>, in sceneView: ARView) -> CGPoint? {
        guard let point = sceneView.project(position) else { return nil }
        // ARView uses AppKit's bottom-left origin; this hosting view is flipped.
        return convert(point, from: sceneView)
    }

    func projectedRect(_ bounds: BoundingBox, in sceneView: ARView) -> CGRect? {
        var points: [CGPoint] = []
        for x in [bounds.min.x, bounds.max.x] {
            for y in [bounds.min.y, bounds.max.y] {
                for z in [bounds.min.z, bounds.max.z] {
                    guard let point = projectedAnchor(SIMD3(x, y, z), in: sceneView) else { return nil }
                    points.append(point)
                }
            }
        }
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
