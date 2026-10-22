import Foundation

/// Die beiden Limit-Fenster des Abos.
public enum LimitKind: String, Codable, CaseIterable, Sendable {
    case fiveHour
    case sevenDay

    public var title: String {
        switch self {
        case .fiveHour: "5-Stunden-Fenster"
        case .sevenDay: "Wochenlimit"
        }
    }
}

extension ClaudeStatusSnapshot {
    public func window(_ kind: LimitKind) -> RateLimitWindow? {
        switch kind {
        case .fiveHour: fiveHour
        case .sevenDay: sevenDay
        }
    }
}

/// Eine fällige Mitteilung: ein Fenster hat eine Schwelle überschritten.
public struct ThresholdAlert: Equatable, Sendable {
    public var kind: LimitKind
    public var threshold: Double
    public var usedPercentage: Double
    public var resetsAt: Date
}

/// Merkt sich pro Fenster, welche Schwelle schon gemeldet wurde, damit jede
/// Schwelle pro Fenster nur einmal meldet – auch über App-Neustarts hinweg.
public struct AlertState: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var resetsAt: Date
        var threshold: Double
    }

    /// Schlüssel ist `LimitKind.rawValue`
    var entries: [String: Entry] = [:]

    public init() {}

    /// Liefert neu überschrittene Schwellen, ohne sie als gemeldet zu markieren.
    /// Pro Fenster höchstens eine Mitteilung, nämlich für die höchste überschrittene Schwelle.
    public func pendingAlerts(
        for snapshot: ClaudeStatusSnapshot,
        thresholds: [Double],
        at now: Date
    ) -> [ThresholdAlert] {
        LimitKind.allCases.compactMap { kind in
            // Abgelaufene Fenster melden nichts mehr
            guard let window = snapshot.window(kind), now < window.resetsAt else { return nil }
            // Bei neuem Fenster beginnt die Zählung wieder bei null
            let entry = entries[kind.rawValue]
            let notified = entry?.resetsAt == window.resetsAt ? entry?.threshold ?? 0 : 0

            guard let crossed = thresholds.filter({ $0 > 0 && window.usedPercentage >= $0 }).max(),
                  crossed > notified else { return nil }
            return ThresholdAlert(
                kind: kind,
                threshold: crossed,
                usedPercentage: window.usedPercentage,
                resetsAt: window.resetsAt
            )
        }
    }

    /// Markiert eine Mitteilung als zugestellt; erst danach gilt die Schwelle als gemeldet.
    public mutating func markNotified(_ alert: ThresholdAlert) {
        if let entry = entries[alert.kind.rawValue] {
            // Verspätete Zustellung darf weder ein neueres Fenster noch eine höhere Schwelle verdrängen
            if entry.resetsAt > alert.resetsAt { return }
            if entry.resetsAt == alert.resetsAt, entry.threshold >= alert.threshold { return }
        }
        entries[alert.kind.rawValue] = Entry(resetsAt: alert.resetsAt, threshold: alert.threshold)
    }
}
