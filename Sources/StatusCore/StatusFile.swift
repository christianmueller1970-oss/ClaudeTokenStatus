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
