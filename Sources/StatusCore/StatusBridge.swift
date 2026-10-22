import Foundation

/// Logik der Statuszeilen-Bridge, getrennt vom Executable, damit sie testbar ist.
public enum StatusBridge {
    public struct Result: Equatable, Sendable {
        /// Zu schreibender Snapshot; `nil`, wenn der Input unbrauchbar war
        public var snapshot: ClaudeStatusSnapshot?
        /// Zeile für die Claude-Code-Statuszeile
        public var line: String
    }

    public static let unreadableLine = "ClaudeTokenStatus: JSON nicht lesbar"

    /// Verarbeitet einen Statuszeilen-Input von Claude Code.
    /// Bei unbrauchbarem Input bleibt `status.json` unangetastet.
    public static func process(input: Data, previous: ClaudeStatusSnapshot?, now: Date) -> Result {
        guard let fresh = try? ClaudeStatusSnapshot(statusLineJSON: input, capturedAt: now) else {
            return Result(snapshot: nil, line: unreadableLine)
        }
        let merged = fresh.merged(withPrevious: previous)
        return Result(snapshot: merged, line: statusLine(for: merged, at: now))
    }

    /// Kompakte Zeile, z. B. `5h 42% · 7d 18% · ctx 31%`.
    /// Fehlende Werte erscheinen als «–», geschätzte (nach Reset) mit «~».
    public static func statusLine(for snapshot: ClaudeStatusSnapshot, at now: Date) -> String {
        [
            "5h \(format(snapshot.fiveHour?.effective(at: now)))",
            "7d \(format(snapshot.sevenDay?.effective(at: now)))",
            "ctx \(format(snapshot.contextUsedPercentage))",
        ].joined(separator: " · ")
    }

    private static func format(_ window: EffectiveWindow?) -> String {
        guard let window else { return "–" }
        return (window.isEstimated ? "~" : "") + format(window.usedPercentage)
    }

    private static func format(_ percentage: Double?) -> String {
        guard let percentage else { return "–" }
        return "\(Int(percentage.rounded()))%"
    }
}
