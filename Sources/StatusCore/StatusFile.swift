import Foundation

/// Lesen und Schreiben von `status.json`, der Schnittstelle zwischen Bridge und App.
public enum StatusFile {
    /// `~/Library/Application Support/ClaudeTokenStatus/status.json`
    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClaudeTokenStatus", isDirectory: true)
            .appendingPathComponent("status.json")
    }

    public static func read(from url: URL = defaultURL) throws -> ClaudeStatusSnapshot {
        try decoder.decode(ClaudeStatusSnapshot.self, from: Data(contentsOf: url))
    }

    /// Schreibt atomar (temporäre Datei + Umbenennen), damit die App nie halbe Dateien liest.
    public static func write(_ snapshot: ClaudeStatusSnapshot, to url: URL = defaultURL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }

    /// Lesen, Ändern und Schreiben unter einer prozessübergreifenden Sperre,
    /// damit parallele Bridges (mehrere Claude-Code-Sessions) sich nicht gegenseitig überschreiben.
    /// Gibt `transform` `nil` zurück, bleibt die Datei unverändert.
    public static func update(
        at url: URL = defaultURL,
        _ transform: (ClaudeStatusSnapshot?) throws -> ClaudeStatusSnapshot?
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Eigene Lockdatei, weil status.json beim atomaren Schreiben ersetzt wird
        let descriptor = open(url.appendingPathExtension("lock").path, O_CREAT | O_RDWR, 0o600)
        guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { close(descriptor) }
        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { flock(descriptor, LOCK_UN) }

        // Fehlende oder kaputte Datei zählt als «kein Vorgänger»
        let previous = try? read(from: url)
        if let next = try transform(previous) {
            try write(next, to: url)
        }
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
