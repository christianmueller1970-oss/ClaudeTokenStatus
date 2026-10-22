import Foundation
import Observation
import StatusCore

/// Hält den aktuellen Snapshot aus `status.json` und lädt bei jeder Änderung neu.
@MainActor
@Observable
final class StatusModel {
    private(set) var snapshot: ClaudeStatusSnapshot?
    private(set) var readError: String?

    let fileURL: URL
    @ObservationIgnored private var watcher: DirectoryWatcher?

    init(fileURL: URL = StatusFile.defaultURL) {
        self.fileURL = fileURL
        let directory = fileURL.deletingLastPathComponent()
        // Ordner anlegen, damit er beobachtet werden kann, bevor die Bridge je lief
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        reload()
        watcher = DirectoryWatcher(url: directory) { [weak self] in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    func reload() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            snapshot = nil
            readError = nil
            return
        }
        do {
            snapshot = try StatusFile.read(from: fileURL)
            readError = nil
        } catch {
            // Letzten guten Stand behalten, Fehler nur anzeigen
            readError = error.localizedDescription
        }
    }
}
