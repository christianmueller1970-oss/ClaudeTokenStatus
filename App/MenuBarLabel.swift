import AppKit
import StatusCore
import SwiftUI

/// Menüleiste: Ring mit Ampelfarbe und Prozentwert des 5-Stunden-Fensters.
struct MenuBarLabel: View {
    let model: StatusModel

    var body: some View {
        TimelineView(.everyMinute) { context in
            let window = model.snapshot?.fiveHour?.effective(at: context.date)
            let isStale = model.snapshot?.isStale(at: context.date) ?? true

            HStack(spacing: 4) {
                Image(nsImage: RingImage.make(fraction: (window?.usedPercentage ?? 0) / 100,
                                              color: color(for: window, isStale: isStale)))
                Text(window.map { "\(Int($0.usedPercentage.rounded()))%" } ?? "–")
                    .monospacedDigit()
            }
        }
    }

    private func color(for window: EffectiveWindow?, isStale: Bool) -> NSColor {
        guard let window, !isStale else { return .secondaryLabelColor }
        return window.level.nsColor
    }
}

extension UsageLevel {
    var nsColor: NSColor {
        switch self {
        case .normal: .systemGreen
        case .warning: .systemOrange
        case .critical: .systemRed
        }
    }

    var color: Color { Color(nsColor: nsColor) }
}

/// Zeichnet den Ring als Bild, weil die Menüleiste SwiftUI-Farben sonst einfärbt.
enum RingImage {
    static func make(fraction: Double, color: NSColor, size: CGFloat = 14) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let lineWidth: CGFloat = 2.2
            let inset = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            let center = NSPoint(x: inset.midX, y: inset.midY)
            let radius = inset.width / 2

            let track = NSBezierPath(ovalIn: inset)
            track.lineWidth = lineWidth
            NSColor.labelColor.withAlphaComponent(0.25).setStroke()
            track.stroke()

            let clamped = min(max(fraction, 0), 1)
            guard clamped > 0 else { return true }
            // Im Uhrzeigersinn ab 12 Uhr
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: 90,
                          endAngle: 90 - 360 * clamped, clockwise: true)
            arc.lineWidth = lineWidth
            arc.lineCapStyle = .round
            color.setStroke()
            arc.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }
}
