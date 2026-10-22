import AppKit
import StatusCore
import SwiftUI

/// Menüleiste: Ring mit Ampelfarbe und Prozentwert des 5-Stunden-Fensters.
/// Beides wird als ein einziges Bild gezeichnet, weil `MenuBarExtra` nur einfache
/// Bilder und Texte zuverlässig darstellt.
struct MenuBarLabel: View {
    let model: StatusModel

    var body: some View {
        let window = model.snapshot?.fiveHour?.effective(at: model.now)
        let isStale = model.snapshot?.isStale(at: model.now) ?? true

        Image(nsImage: MenuBarImage.make(
            fraction: (window?.usedPercentage ?? 0) / 100,
            color: color(for: window, isStale: isStale),
            text: window.map { "\(Int($0.usedPercentage.rounded()))%" } ?? "–"
        ))
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

/// Ring plus Text als nicht-templatefähiges Bild, damit die Ampelfarbe erhalten bleibt.
enum MenuBarImage {
    static func make(fraction: Double, color: NSColor, text: String) -> NSImage {
        let ringSize: CGFloat = 14
        let spacing: CGFloat = 4
        let height: CGFloat = 18
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let size = NSSize(width: ceil(ringSize + spacing + textSize.width), height: height)

        let image = NSImage(size: size, flipped: false) { _ in
            let ringRect = NSRect(x: 0, y: (height - ringSize) / 2, width: ringSize, height: ringSize)
            drawRing(in: ringRect, fraction: fraction, color: color)

            // Farbe erst beim Zeichnen auflösen, damit sie zum Erscheinungsbild der Menüleiste passt
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
            let textOrigin = NSPoint(x: ringSize + spacing, y: (height - textSize.height) / 2)
            (text as NSString).draw(at: textOrigin, withAttributes: attributes)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawRing(in rect: NSRect, fraction: Double, color: NSColor) {
        let lineWidth: CGFloat = 2.2
        let inset = rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        let center = NSPoint(x: inset.midX, y: inset.midY)

        let track = NSBezierPath(ovalIn: inset)
        track.lineWidth = lineWidth
        NSColor.labelColor.withAlphaComponent(0.25).setStroke()
        track.stroke()

        let clamped = min(max(fraction, 0), 1)
        guard clamped > 0 else { return }
        // Im Uhrzeigersinn ab 12 Uhr
        let arc = NSBezierPath()
        arc.appendArc(withCenter: center, radius: inset.width / 2, startAngle: 90,
                      endAngle: 90 - 360 * clamped, clockwise: true)
        arc.lineWidth = lineWidth
        arc.lineCapStyle = .round
        color.setStroke()
        arc.stroke()
    }
}
