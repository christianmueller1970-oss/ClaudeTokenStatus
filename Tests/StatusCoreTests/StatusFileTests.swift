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
