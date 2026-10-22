import Foundation
import Observation
import StatusCore

/// Hält den aktuellen Snapshot aus `status.json` und lädt bei jeder Änderung neu.
@MainActor
@Observable
final class StatusModel {
    private(set) var snapshot: ClaudeStatusSnapshot?
    private(set) var readError: String?
    /// Minütlich aktualisiert, damit Menüleiste, Countdown und Alter weiterlaufen
    private(set) var now = Date()

    let fileURL: URL
    @ObservationIgnored private var watcher: DirectoryWatcher?
    @ObservationIgnored private var clock: Timer?
    @ObservationIgnored private let notifier = UsageNotifier()

    init(fileURL: URL = StatusFile.defaultURL) {
        self.fileURL = fileURL
        let directory = fileURL.deletingLastPathComponent()
        // Ordner anlegen, damit er beobachtet werden kann, bevor die Bridge je lief
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        reload()
        watcher = DirectoryWatcher(url: directory) { [weak self] in
            MainActor.assumeIsolated { self?.reload() }
        }
        let clock = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.now = Date() }
        }
        // Grosszügige Toleranz, damit macOS Wakeups bündeln kann (Akku)
        clock.tolerance = 10
        RunLoop.main.add(clock, forMode: .common)
        self.clock = clock
    }

    func reload() {
        now = Date()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            snapshot = nil
            readError = nil
            return
        }
        do {
            let snapshot = try StatusFile.read(from: fileURL)
            self.snapshot = snapshot
            readError = nil
            notifier.check(snapshot, at: now)
        } catch {
            // Letzten guten Stand behalten, Fehler nur anzeigen
            readError = error.localizedDescription
        }
    }
}
