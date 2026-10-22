import Foundation
import Testing
@testable import StatusCore

@Suite("status.json lesen und schreiben")
struct StatusFileTests {
    @Test("Roundtrip über eine temporäre Datei, Ordner wird angelegt")
    func roundTrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StatusFileTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("sub/status.json")

        // ISO-8601 speichert ganze Sekunden, darum keine Bruchteile im Testdatum
        let snapshot = ClaudeStatusSnapshot(
            fiveHour: RateLimitWindow(usedPercentage: 16, resetsAt: Date(timeIntervalSince1970: 1_792_701_000)),
            sevenDay: nil,
            contextUsedPercentage: 8,
            sessionCostUSD: 1.25,
            modelName: "Opus 5.5",
            sessionID: "abc",
            capturedAt: Date(timeIntervalSince1970: 1_792_690_000)
        )

        try StatusFile.write(snapshot, to: url)
        #expect(try StatusFile.read(from: url) == snapshot)
    }

    @Test("Fehlende Datei wirft")
    func missingFileThrows() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("gibt-es-nicht-\(UUID().uuidString).json")
        #expect(throws: (any Error).self) { try StatusFile.read(from: url) }
    }
}

@Suite("status.json unter Sperre aktualisieren")
struct StatusFileUpdateTests {
    @Test("Parallele Updates gehen nicht verloren")
    func concurrentUpdatesAreSerialized() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StatusFileUpdateTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("status.json")
        let start = Date(timeIntervalSince1970: 1_792_690_000)

        // Jedes Update zählt contextUsedPercentage um eins hoch; ohne Sperre gingen Schritte verloren
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<40 {
                group.addTask {
                    try StatusFile.update(at: url) { previous in
                        var next = previous ?? ClaudeStatusSnapshot(contextUsedPercentage: 0, capturedAt: start)
                        next.contextUsedPercentage = (next.contextUsedPercentage ?? 0) + 1
                        return next
                    }
                }
            }
            try await group.waitForAll()
        }

        #expect(try StatusFile.read(from: url).contextUsedPercentage == 40)
    }

    @Test("nil aus transform lässt die Datei unverändert")
    func nilKeepsFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StatusFileUpdateTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("status.json")
        let snapshot = ClaudeStatusSnapshot(modelName: "Opus 5.5", capturedAt: Date(timeIntervalSince1970: 1_792_690_000))
        try StatusFile.write(snapshot, to: url)

        try StatusFile.update(at: url) { previous in
            #expect(previous == snapshot)
            return nil
        }
        #expect(try StatusFile.read(from: url) == snapshot)
    }
}
