import Foundation

/// Kurze deutsche Zeitangaben für die Anzeige, z. B. «2 h 14 min» oder «1 T 22 h».
public enum DurationText {
    /// Zeitspanne mit den zwei grössten sinnvollen Einheiten; negative Werte zählen als 0.
    public static func short(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval / 60))
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "\(days) T \(hours) h" : "\(days) T"
        }
        if hours > 0 {
            return minutes > 0 ? "\(hours) h \(minutes) min" : "\(hours) h"
        }
        return "\(minutes) min"
    }

    /// «gerade eben» unter einer Minute, sonst «vor 3 min»
    public static func ago(_ interval: TimeInterval) -> String {
        interval < 60 ? "gerade eben" : "vor \(short(interval))"
    }
}
