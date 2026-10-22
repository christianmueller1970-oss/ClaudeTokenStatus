import Foundation
import StatusCore
import UserNotifications

/// Verschickt eine Mitteilung, wenn ein Limit eine Schwelle überschreitet.
@MainActor
final class UsageNotifier {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func check(_ snapshot: ClaudeStatusSnapshot, at now: Date) {
        guard defaults.bool(forKey: AppSettings.notificationsEnabled) else { return }

        var state = loadState()
        let alerts = state.alerts(for: snapshot, thresholds: AppSettings.thresholds(in: defaults), at: now)
        saveState(state)
        guard !alerts.isEmpty else { return }

        Task {
            // Fragt nur beim ersten Mal nach, danach kommt die gespeicherte Antwort
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            for alert in alerts {
                try? await center.add(Self.request(for: alert, now: now))
            }
        }
    }

    private static func request(for alert: ThresholdAlert, now: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Claude: \(alert.kind.title) bei \(Int(alert.usedPercentage.rounded())) %"
        let time = alert.resetsAt.formatted(date: .omitted, time: .shortened)
        content.body = "Reset in \(DurationText.short(alert.resetsAt.timeIntervalSince(now))) (\(time))."
        content.sound = .default
        let id = "\(alert.kind.rawValue)-\(Int(alert.resetsAt.timeIntervalSince1970))-\(Int(alert.threshold))"
        return UNNotificationRequest(identifier: id, content: content, trigger: nil)
    }

    private func loadState() -> AlertState {
        guard let data = defaults.data(forKey: AppSettings.alertState),
              let state = try? JSONDecoder().decode(AlertState.self, from: data) else {
            return AlertState()
        }
        return state
    }

    private func saveState(_ state: AlertState) {
        defaults.set(try? JSONEncoder().encode(state), forKey: AppSettings.alertState)
    }
}
