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

    /// Liefert neu überschrittene Schwellen und merkt sie sich.
    /// Pro Fenster höchstens eine Mitteilung, nämlich für die höchste überschrittene Schwelle.
    public mutating func alerts(
        for snapshot: ClaudeStatusSnapshot,
        thresholds: [Double],
        at now: Date
    ) -> [ThresholdAlert] {
        var alerts: [ThresholdAlert] = []

        for kind in LimitKind.allCases {
            // Abgelaufene Fenster melden nichts mehr
            guard let window = snapshot.window(kind), now < window.resetsAt else { continue }

            var entry = entries[kind.rawValue] ?? Entry(resetsAt: window.resetsAt, threshold: 0)
            if entry.resetsAt != window.resetsAt {
                // Neues Fenster: wieder bei null beginnen
                entry = Entry(resetsAt: window.resetsAt, threshold: 0)
            }

            if let crossed = thresholds.filter({ $0 > 0 && window.usedPercentage >= $0 }).max(),
               crossed > entry.threshold {
                alerts.append(ThresholdAlert(
                    kind: kind,
                    threshold: crossed,
                    usedPercentage: window.usedPercentage,
                    resetsAt: window.resetsAt
                ))
                entry.threshold = crossed
            }
            entries[kind.rawValue] = entry
        }
        return alerts
    }
}
