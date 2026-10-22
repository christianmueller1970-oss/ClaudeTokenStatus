import Foundation
import Testing
@testable import StatusCore

@Suite("Statuszeilen-JSON lesen")
struct StatusLineParsingTests {
    let capturedAt = Date(timeIntervalSince1970: 1_792_690_000)

    @Test("Echtes Pro/Max-JSON liefert beide Limits und Session-Infos")
    func parsesRealProPayload() throws {
        let snapshot = try ClaudeStatusSnapshot(statusLineJSON: fixture("statusline-pro"), capturedAt: capturedAt)

        #expect(snapshot.fiveHour == RateLimitWindow(usedPercentage: 16, resetsAt: Date(timeIntervalSince1970: 1_792_701_000)))
        #expect(snapshot.sevenDay == RateLimitWindow(usedPercentage: 17, resetsAt: Date(timeIntervalSince1970: 1_792_864_800)))
        #expect(snapshot.contextUsedPercentage == 8)
        #expect(snapshot.modelName == "Opus 5.5")
        #expect(snapshot.sessionID == "00000000-0000-0000-0000-000000000001")
        #expect(snapshot.capturedAt == capturedAt)
        let cost = try #require(snapshot.sessionCostUSD)
        #expect(abs(cost - 1.0897) < 0.001)
    }

    @Test("Frische Session ohne rate_limits und mit null-Werten")
    func parsesNewSessionWithoutLimits() throws {
        let snapshot = try ClaudeStatusSnapshot(statusLineJSON: fixture("statusline-new-session"), capturedAt: capturedAt)

        #expect(snapshot.fiveHour == nil)
        #expect(snapshot.sevenDay == nil)
        #expect(snapshot.contextUsedPercentage == nil)
        #expect(snapshot.sessionCostUSD == 0)
    }

    @Test("Leeres Objekt ist gültig, alles bleibt nil")
    func parsesEmptyObject() throws {
        let snapshot = try ClaudeStatusSnapshot(statusLineJSON: Data("{}".utf8), capturedAt: capturedAt)
        #expect(snapshot == ClaudeStatusSnapshot(capturedAt: capturedAt))
    }

    @Test("Unvollständiges oder falsch typisiertes Fenster wird ignoriert, der Rest bleibt")
    func ignoresBrokenWindow() throws {
        let json = """
        {
          "model": "kein Objekt",
          "rate_limits": {
            "five_hour": { "used_percentage": 50 },
            "seven_day": { "used_percentage": "viel", "resets_at": 1792864800 }
          },
          "context_window": { "used_percentage": 12.5 }
        }
        """
        let snapshot = try ClaudeStatusSnapshot(statusLineJSON: Data(json.utf8), capturedAt: capturedAt)

        #expect(snapshot.fiveHour == nil)
        #expect(snapshot.sevenDay == nil)
        #expect(snapshot.modelName == nil)
        #expect(snapshot.contextUsedPercentage == 12.5)
    }

    @Test("Prozentwerte ausserhalb 0–100 werden begrenzt")
    func clampsPercentage() throws {
        let json = #"{"rate_limits":{"five_hour":{"used_percentage":104,"resets_at":1792701000}}}"#
        let snapshot = try ClaudeStatusSnapshot(statusLineJSON: Data(json.utf8), capturedAt: capturedAt)
        #expect(snapshot.fiveHour?.usedPercentage == 100)
    }

    @Test("Ungültiges JSON wirft")
    func throwsOnInvalidJSON() {
        #expect(throws: (any Error).self) {
            try ClaudeStatusSnapshot(statusLineJSON: Data("kaputt".utf8))
        }
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }
}

@Suite("Snapshots zusammenführen und Alter")
struct SnapshotMergeTests {
    let reset = Date(timeIntervalSince1970: 1_792_701_000)

    @Test("Frische Session ohne Limits übernimmt die bekannten Limits")
    func keepsPreviousLimitsWhenMissing() {
        let previous = ClaudeStatusSnapshot(
            fiveHour: RateLimitWindow(usedPercentage: 16, resetsAt: reset),
            sevenDay: RateLimitWindow(usedPercentage: 17, resetsAt: reset.addingTimeInterval(86_400)),
            modelName: "Opus 5.5",
            capturedAt: reset.addingTimeInterval(-3_600)
        )
        let fresh = ClaudeStatusSnapshot(modelName: "Fable 5.1", sessionID: "neu", capturedAt: reset.addingTimeInterval(-60))

        let merged = fresh.merged(withPrevious: previous)

        #expect(merged.fiveHour == previous.fiveHour)
        #expect(merged.sevenDay == previous.sevenDay)
        #expect(merged.modelName == "Fable 5.1")
        #expect(merged.sessionID == "neu")
        #expect(merged.capturedAt == fresh.capturedAt)
    }

    @Test("Übernommene Limits behalten ihr Alter, frische Limits sind sofort aktuell")
    func limitAgeSurvivesMerge() throws {
        let old = reset.addingTimeInterval(-3 * 3_600)
        let now = reset.addingTimeInterval(-60)
        let withLimits = #"{"rate_limits":{"five_hour":{"used_percentage":40,"resets_at":1792701000}}}"#

        let previous = try ClaudeStatusSnapshot(statusLineJSON: Data(withLimits.utf8), capturedAt: old)
        #expect(previous.limitsUpdatedAt == old)

        // Frische Session ohne Limits: Snapshot neu, Limits bleiben 3 h alt und damit veraltet
        let fresh = try ClaudeStatusSnapshot(statusLineJSON: Data(#"{"session_id":"neu"}"#.utf8), capturedAt: now)
        #expect(fresh.limitsUpdatedAt == nil)
        let carried = fresh.merged(withPrevious: previous)
        #expect(carried.capturedAt == now)
        #expect(carried.limitsUpdatedAt == old)
        #expect(carried.isStale(at: now))

        // Kommen wieder echte Limits, ist der Wert frisch
        let updated = try ClaudeStatusSnapshot(statusLineJSON: Data(withLimits.utf8), capturedAt: now)
            .merged(withPrevious: carried)
        #expect(updated.limitsUpdatedAt == now)
        #expect(!updated.isStale(at: now))
    }

    @Test("Älterer Vorgänger ohne limitsUpdatedAt zählt mit seinem capturedAt")
    func legacyPreviousUsesCapturedAt() {
        let old = reset.addingTimeInterval(-3 * 3_600)
        let previous = ClaudeStatusSnapshot(fiveHour: RateLimitWindow(usedPercentage: 5, resetsAt: reset), capturedAt: old)
        let merged = ClaudeStatusSnapshot(capturedAt: reset.addingTimeInterval(-60)).merged(withPrevious: previous)
        #expect(merged.limitsUpdatedAt == old)
    }

    @Test("Ohne Vorgänger bleibt der Snapshot unverändert")
    func mergeWithoutPrevious() {
        let snapshot = ClaudeStatusSnapshot(fiveHour: RateLimitWindow(usedPercentage: 5, resetsAt: reset), capturedAt: reset)
        #expect(snapshot.merged(withPrevious: nil) == snapshot)
    }

    @Test("Gleiches Fenster: höherer Verbrauch gewinnt (veraltete Session)")
    func sameWindowTakesHigherUsage() {
        let current = RateLimitWindow(usedPercentage: 40, resetsAt: reset)
        let stale = RateLimitWindow(usedPercentage: 25, resetsAt: reset)
        #expect(RateLimitWindow.merge(stale, current) == current)
        #expect(RateLimitWindow.merge(current, stale) == current)
    }

    @Test("Verschiedene Fenster: das neuere gewinnt, auch bei tieferem Verbrauch")
    func newerWindowWins() {
        let old = RateLimitWindow(usedPercentage: 95, resetsAt: reset)
        let new = RateLimitWindow(usedPercentage: 3, resetsAt: reset.addingTimeInterval(5 * 3_600))
        #expect(RateLimitWindow.merge(old, new) == new)
        #expect(RateLimitWindow.merge(new, old) == new)
    }

    @Test("Veraltet erst nach mehr als 30 Minuten")
    func staleness() {
        let snapshot = ClaudeStatusSnapshot(capturedAt: reset)
        #expect(!snapshot.isStale(at: reset.addingTimeInterval(30 * 60)))
        #expect(snapshot.isStale(at: reset.addingTimeInterval(30 * 60 + 1)))
        #expect(snapshot.age(at: reset.addingTimeInterval(90)) == 90)
    }
}
