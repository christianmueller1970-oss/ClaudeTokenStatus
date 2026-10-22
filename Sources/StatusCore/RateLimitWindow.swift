import Foundation

/// Ein Limit-Fenster des Abos (5 Stunden oder 7 Tage), wie es Claude Code meldet.
public struct RateLimitWindow: Codable, Equatable, Sendable {
    /// Verbrauch in Prozent (0–100)
    public var usedPercentage: Double
    /// Zeitpunkt, an dem das Fenster zurückgesetzt wird
    public var resetsAt: Date

    public init(usedPercentage: Double, resetsAt: Date) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }

    /// Wert für die Anzeige zum Zeitpunkt `now`.
    /// Ist der Reset vorbei, gilt das Fenster als leer – das ist eine Schätzung,
    /// bis Claude Code wieder einen echten Wert liefert.
    public func effective(at now: Date) -> EffectiveWindow {
        if now >= resetsAt {
            return EffectiveWindow(usedPercentage: 0, resetsAt: nil, isEstimated: true)
        }
        return EffectiveWindow(usedPercentage: usedPercentage, resetsAt: resetsAt, isEstimated: false)
    }

    /// Führt zwei Meldungen desselben Fensters zusammen (z. B. aus parallelen Sessions).
    /// - gleiches Fenster (gleicher Reset): der höhere Verbrauch gewinnt, da er innerhalb
    ///   eines Fensters nur steigen kann
    /// - verschiedene Fenster: das neuere (späterer Reset) gewinnt
    /// - fehlt eine Meldung, bleibt die andere erhalten
    public static func merge(_ lhs: RateLimitWindow?, _ rhs: RateLimitWindow?) -> RateLimitWindow? {
        guard let lhs else { return rhs }
        guard let rhs else { return lhs }
        if lhs.resetsAt == rhs.resetsAt {
            return lhs.usedPercentage >= rhs.usedPercentage ? lhs : rhs
        }
        return lhs.resetsAt > rhs.resetsAt ? lhs : rhs
    }
}

/// Anzeigewert eines Fensters zu einem bestimmten Zeitpunkt.
public struct EffectiveWindow: Equatable, Sendable {
    public var usedPercentage: Double
    /// `nil`, wenn der nächste Reset unbekannt ist (Fenster bereits abgelaufen)
    public var resetsAt: Date?
    /// `true`, wenn der Wert nicht von Claude Code stammt, sondern angenommen ist
    public var isEstimated: Bool

    public var remainingPercentage: Double { max(0, 100 - usedPercentage) }

    public var level: UsageLevel { UsageLevel(usedPercentage: usedPercentage) }
}

/// Ampelstufe für die Anzeige.
public enum UsageLevel: Equatable, Sendable {
    case normal
    case warning
    case critical

    public static let warningThreshold: Double = 70
    public static let criticalThreshold: Double = 90

    public init(usedPercentage: Double) {
        switch usedPercentage {
        case Self.criticalThreshold...: self = .critical
        case Self.warningThreshold...: self = .warning
        default: self = .normal
        }
    }
}
