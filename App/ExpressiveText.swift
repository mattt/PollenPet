import AppKit
import SwiftUI

struct ExpressiveText: View {
    let text: Text
    let time: Double
    let complete: Bool
    @Environment(\.reducePetMotion) private var reducedMotion

    var body: some View {
        text
            .font(AppTypography.dialogue(SpeechText.fontSize))
            .lineSpacing(8)
            .textRenderer(SpeechRenderer(time: time, reducedMotion: reducedMotion, complete: complete))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SpeechText {
    static let fontSize: CGFloat = 25

    let text: Text

    init(_ performance: Performance, lineWidth: CGFloat) {
        let breakIndex = Self.sentenceBreakIndex(in: performance.units, lineWidth: lineWidth)
        // Every fragment is a whole extended grapheme cluster. All of its glyphs inherit
        // the same timing, including emoji sequences and combining marks.
        text = performance.units.enumerated().reduce(Text("")) { result, element in
            let (index, unit) = element
            let displayedText = index == breakIndex ? "\n" : unit.text
            return result + Text(verbatim: displayedText).customAttribute(SpeechAttribute(
                id: unit.id, start: unit.start, end: unit.effectEnd, effect: unit.effect
            ))
        }
    }

    private static func sentenceBreakIndex(in units: [RevealUnit], lineWidth: CGFloat) -> Int? {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        func width(_ text: String) -> CGFloat {
            (text as NSString).size(withAttributes: [.font: font]).width
        }
        guard width(units.map(\.text).joined()) > lineWidth else { return nil }

        // Keep short dialogue on one line. For longer dialogue, prefer a sentence
        // boundary only when both resulting lines fit and neither is very short.
        var best: (index: Int, difference: CGFloat)?
        for index in 0..<(units.count - 1) where ".!?".contains(units[index].text) && units[index + 1].text == " " {
            let first = units[...index].map(\.text).joined()
            let second = units[(index + 2)...].map(\.text).joined()
            let firstWidth = width(first)
            let secondWidth = width(second)
            guard firstWidth <= lineWidth, secondWidth <= lineWidth,
                  min(firstWidth, secondWidth) >= max(firstWidth, secondWidth) * 0.35 else { continue }
            let difference = abs(firstWidth - secondWidth)
            if difference < (best?.difference ?? .infinity) {
                best = (index + 1, difference)
            }
        }
        return best?.index
    }
}

private struct SpeechAttribute: TextAttribute {
    let id: Int
    let start: Double
    let end: Double
    let effect: TextEffect
}

private struct SpeechRenderer: TextRenderer {
    let time: Double
    let reducedMotion: Bool
    let complete: Bool

    var displayPadding: EdgeInsets { .init(top: 16, leading: 10, bottom: 16, trailing: 10) }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                guard let cue = run[SpeechAttribute.self] else {
                    context.draw(run)
                    continue
                }
                guard complete || time >= cue.start else { continue }
                var drawing = context
                let age = max(0, time - cue.start)
                if !complete && !reducedMotion {
                    let entrance = min(1, age / 0.10)
                    drawing.opacity = entrance
                    drawing.translateBy(x: 0, y: (1 - entrance) * 4)
                    let settle = min(1, max(0, (cue.end - time) / 0.4))
                    if cue.effect == .bounce {
                        let phase = age * 8 + Double(cue.id) * 0.55
                        drawing.translateBy(x: 0, y: -abs(sin(phase)) * 4 * settle)
                    }
                }
                drawing.draw(run, options: .disablesSubpixelQuantization)
            }
        }
    }
}
