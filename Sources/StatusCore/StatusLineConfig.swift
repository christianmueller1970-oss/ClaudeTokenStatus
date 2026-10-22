import Foundation

/// Prüft und setzt den `statusLine`-Eintrag in `~/.claude/settings.json`.
/// Alle übrigen Einstellungen bleiben erhalten; vor jedem Schreiben gibt es ein Backup.
public enum StatusLineConfig {
    public enum State: Equatable, Sendable {
        case notConfigured
        case configured
        /// Eine andere Statuszeile ist eingetragen (Befehl)
        case otherCommand(String)
    }

    public enum ConfigError: Error, LocalizedError, Equatable {
        case notAnObject

        public var errorDescription: String? {
            switch self {
            case .notAnObject: "settings.json enthält kein JSON-Objekt und wird nicht angefasst."
            }
        }
    }

    public static var defaultSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    /// Der Befehl, wie er in `statusLine.command` stehen soll (für die Shell maskiert).
    public static func command(forBridgeAt path: String) -> String {
        shellQuoted(path)
    }

    /// Zustand anhand des Dateiinhalts; `nil` heisst, die Datei existiert nicht.
    public static func state(ofSettings data: Data?, bridgePath: String) throws -> State {
        guard let data else { return .notConfigured }
        let settings = try object(from: data)
        guard let statusLine = settings["statusLine"] as? [String: Any],
              let existing = statusLine["command"] as? String else {
            return .notConfigured
        }
        return existing == command(forBridgeAt: bridgePath) ? .configured : .otherCommand(existing)
    }

    /// Neuer Dateiinhalt mit gesetztem `statusLine`, alle anderen Schlüssel unverändert.
    public static func installing(bridgePath: String, intoSettings data: Data?) throws -> Data {
        var settings = try data.map(object(from:)) ?? [:]
        settings["statusLine"] = ["type": "command", "command": command(forBridgeAt: bridgePath)]
        return try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    /// Schreibt die Statuszeile in die Datei und legt vorher ein Backup daneben.
    /// - Returns: Pfad des Backups, `nil` wenn es noch keine Datei gab
    @discardableResult
    public static func install(
        bridgePath: String,
        settingsURL: URL = defaultSettingsURL,
        now: Date = Date()
    ) throws -> URL? {
        let fileManager = FileManager.default
        let existing = fileManager.fileExists(atPath: settingsURL.path) ? try Data(contentsOf: settingsURL) : nil
        // Erst den neuen Inhalt bauen: bei kaputtem JSON wird nichts angefasst
        let updated = try installing(bridgePath: bridgePath, intoSettings: existing)

        var backupURL: URL?
        if existing != nil {
            let url = settingsURL.appendingPathExtension("bak-\(backupStamp(now))")
            try fileManager.copyItem(at: settingsURL, to: url)
            backupURL = url
        } else {
            try fileManager.createDirectory(at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        try updated.write(to: settingsURL, options: .atomic)
        return backupURL
    }

    /// Pfad unverändert, wenn er nur unkritische Zeichen enthält, sonst in einfachen Anführungszeichen.
    static func shellQuoted(_ path: String) -> String {
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/._-+")
        if !path.isEmpty, path.unicodeScalars.allSatisfy(safe.contains) {
            return path
        }
        return "'" + path.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    private static func object(from data: Data) throws -> [String: Any] {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ConfigError.notAnObject
        }
        return object
    }

    private static func backupStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
