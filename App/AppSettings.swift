import Foundation

/// Schlüssel und Standardwerte in UserDefaults.
enum AppSettings {
    static let notificationsEnabled = "notificationsEnabled"
    static let warningThreshold = "warningThreshold"
    static let criticalThreshold = "criticalThreshold"
    static let alertState = "alertState"

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            notificationsEnabled: true,
            warningThreshold: 80.0,
            criticalThreshold: 95.0,
        ])
    }

    static func thresholds(in defaults: UserDefaults = .standard) -> [Double] {
        [defaults.double(forKey: warningThreshold), defaults.double(forKey: criticalThreshold)]
    }

    /// Pfad der eingebetteten Bridge im App-Bundle
    static var bridgePath: String? {
        Bundle.main.url(forAuxiliaryExecutable: "claude-status-bridge")?.path
    }

    static var isInstalledInApplications: Bool {
        Bundle.main.bundlePath.hasPrefix("/Applications/")
    }
}
