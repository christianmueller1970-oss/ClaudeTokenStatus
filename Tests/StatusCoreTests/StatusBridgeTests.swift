import Foundation
import Testing
@testable import StatusCore

@Suite("Statuszeilen-Bridge")
struct StatusBridgeTests {
    let now = Date(timeIntervalSince1970: 1_792_690_000)
    let fiveHourReset = Date(timeIntervalSince1970: 1_792_701_000)
    let sevenDayReset = Date(timeIntervalSince1970: 1_792_864_800)

    @Test("Vollständiger Input ergibt Snapshot und Zeile")
    func fullInput() {
        let json = """
        {"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":1792701000},
                        "seven_day":{"used_percentage":17.6,"resets_at":1792864800}},
         "context_window":{"used_percentage":31}}
        """
        let result = StatusBridge.process(input: Data(json.utf8), previous: nil, now: now)

        #expect(result.line == "5h 42% · 7d 18% · ctx 31%")
        #expect(result.snapshot?.fiveHour == RateLimitWindow(usedPercentage: 42, resetsAt: fiveHourReset))
        #expect(result.snapshot?.capturedAt == now)
    }

    @Test("Frische Session ohne Limits zeigt die bekannten Werte weiter an")
    func freshSessionKeepsPrevious() {
        let previous = ClaudeStatusSnapshot(
            fiveHour: RateLimitWindow(usedPercentage: 16, resetsAt: fiveHourReset),
            sevenDay: RateLimitWindow(usedPercentage: 17, resetsAt: sevenDayReset),
            contextUsedPercentage: 80,
            capturedAt: now.addingTimeInterval(-600)
        )
        let result = StatusBridge.process(input: Data(#"{"session_id":"neu"}"#.utf8), previous: previous, now: now)

        #expect(result.line == "5h 16% · 7d 17% · ctx –")
        #expect(result.snapshot?.fiveHour == previous.fiveHour)
        #expect(result.snapshot?.contextUsedPercentage == nil)
    }

    @Test("Ohne irgendwelche Werte nur Striche")
    func emptyInput() {
        let result = StatusBridge.process(input: Data("{}".utf8), previous: nil, now: now)
        #expect(result.line == "5h – · 7d – · ctx –")
        #expect(result.snapshot != nil)
    }

    @Test("Abgelaufenes Fenster wird als geschätzt markiert")
    func expiredWindowIsEstimated() {
        let snapshot = ClaudeStatusSnapshot(
            fiveHour: RateLimitWindow(usedPercentage: 97, resetsAt: now.addingTimeInterval(-1)),
            sevenDay: RateLimitWindow(usedPercentage: 40, resetsAt: sevenDayReset),
            contextUsedPercentage: 12,
            capturedAt: now
        )
        #expect(StatusBridge.statusLine(for: snapshot, at: now) == "5h ~0% · 7d 40% · ctx 12%")
    }

    @Test("Ungültiger Input: kein Snapshot, status.json bleibt unangetastet")
    func invalidInput() {
        let previous = ClaudeStatusSnapshot(capturedAt: now)
        let result = StatusBridge.process(input: Data("kaputt".utf8), previous: previous, now: now)

        #expect(result.snapshot == nil)
        #expect(result.line == StatusBridge.unreadableLine)
    }
}
