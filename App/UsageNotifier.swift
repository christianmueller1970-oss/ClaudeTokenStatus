import Foundation
import StatusCore
import UserNotifications

/// Verschickt eine Mitteilung, wenn ein Limit eine Schwelle überschreitet.
/// Eine Schwelle gilt erst nach erfolgreicher Zustellung als gemeldet, damit z. B.
/// eine später erteilte Erlaubnis die Warnung nicht für das ganze Fenster verschluckt.
@MainActor
final class UsageNotifier {
    private let defaults: UserDefaults
    /// Mitteilungen, die gerade zugestellt werden; verhindert Doppelte bei schnell
    /// aufeinanderfolgenden Datei-Events
    private var inFlight: Set<String> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func check(_ snapshot: ClaudeStatusSnapshot, at now: Date) {
        guard defaults.bool(forKey: AppSettings.notificationsEnabled) else { return }

        let alerts = loadState()
            .pendingAlerts(for: snapshot, thresholds: AppSettings.thresholds(in: defaults), at: now)
            .filter { !inFlight.contains(Self.identifier(for: $0)) }
        guard !alerts.isEmpty else { return }
        alerts.forEach { inFlight.insert(Self.identifier(for: $0)) }

        Task {
            defer { alerts.forEach { inFlight.remove(Self.identifier(for: $0)) } }
            // Fragt nur beim ersten Mal nach, danach kommt die gespeicherte Antwort
            let center = UNUserNotificationCenter.current()
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            for alert in alerts {
                do {
                    try await center.add(Self.request(for: alert, now: now))
                    // Zustand frisch laden, weil sich andere Zustellungen dazwischen gemerkt haben können
                    var state = loadState()
                    state.markNotified(alert)
                    saveState(state)
                } catch {
                    // Nicht markiert: beim nächsten Update erneut versuchen
                }
            }
        }
    }

    private static func identifier(for alert: ThresholdAlert) -> String {
        "\(alert.kind.rawValue)-\(Int(alert.resetsAt.timeIntervalSince1970))-\(Int(alert.threshold))"
    }

    private static func request(for alert: ThresholdAlert, now: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Claude: \(alert.kind.title) bei \(Int(alert.usedPercentage.rounded())) %"
        let time = alert.resetsAt.formatted(date: .omitted, time: .shortened)
        content.body = "Reset in \(DurationText.short(alert.resetsAt.timeIntervalSince(now))) (\(time))."
        content.sound = .default
        return UNNotificationRequest(identifier: identifier(for: alert), content: content, trigger: nil)
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
