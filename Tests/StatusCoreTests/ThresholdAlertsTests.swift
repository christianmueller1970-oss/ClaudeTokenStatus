import Foundation
import Testing
@testable import StatusCore

@Suite("Mitteilungen bei Schwellen")
struct ThresholdAlertsTests {
    let now = Date(timeIntervalSince1970: 1_792_690_000)
    let reset = Date(timeIntervalSince1970: 1_792_701_000)
    let thresholds: [Double] = [80, 95]

    private func snapshot(fiveHour: Double?, reset: Date? = nil, sevenDay: Double? = nil) -> ClaudeStatusSnapshot {
        ClaudeStatusSnapshot(
            fiveHour: fiveHour.map { RateLimitWindow(usedPercentage: $0, resetsAt: reset ?? self.reset) },
            sevenDay: sevenDay.map { RateLimitWindow(usedPercentage: $0, resetsAt: self.reset.addingTimeInterval(86_400)) },
            capturedAt: now
        )
    }

    @Test("Unter der ersten Schwelle keine Mitteilung")
    func belowThreshold() {
        var state = AlertState()
        #expect(state.alerts(for: snapshot(fiveHour: 79), thresholds: thresholds, at: now).isEmpty)
    }

    @Test("Jede Schwelle meldet pro Fenster genau einmal")
    func eachThresholdOnce() {
        var state = AlertState()

        let first = state.alerts(for: snapshot(fiveHour: 80), thresholds: thresholds, at: now)
        #expect(first.map(\.threshold) == [80])
        #expect(first.first?.kind == .fiveHour)
        #expect(state.alerts(for: snapshot(fiveHour: 88), thresholds: thresholds, at: now).isEmpty)
        #expect(state.alerts(for: snapshot(fiveHour: 96), thresholds: thresholds, at: now).map(\.threshold) == [95])
        #expect(state.alerts(for: snapshot(fiveHour: 99), thresholds: thresholds, at: now).isEmpty)
    }

    @Test("Sprung über beide Schwellen meldet nur die höchste")
    func jumpReportsHighestOnly() {
        var state = AlertState()
        let alerts = state.alerts(for: snapshot(fiveHour: 97), thresholds: thresholds, at: now)
        #expect(alerts.map(\.threshold) == [95])
        #expect(state.alerts(for: snapshot(fiveHour: 97), thresholds: thresholds, at: now).isEmpty)
    }

    @Test("Neues Fenster meldet wieder von vorn")
    func newWindowResets() {
        var state = AlertState()
        _ = state.alerts(for: snapshot(fiveHour: 96), thresholds: thresholds, at: now)

        let nextReset = reset.addingTimeInterval(5 * 3_600)
        let alerts = state.alerts(for: snapshot(fiveHour: 81, reset: nextReset), thresholds: thresholds, at: now)
        #expect(alerts.map(\.threshold) == [80])
    }

    @Test("Abgelaufenes Fenster meldet nichts")
    func expiredWindowIsSilent() {
        var state = AlertState()
        #expect(state.alerts(for: snapshot(fiveHour: 99), thresholds: thresholds, at: reset).isEmpty)
    }

    @Test("Beide Fenster werden unabhängig gemeldet")
    func bothKinds() {
        var state = AlertState()
        let alerts = state.alerts(for: snapshot(fiveHour: 85, sevenDay: 95), thresholds: thresholds, at: now)
        #expect(alerts.map(\.kind) == [.fiveHour, .sevenDay])
        #expect(alerts.map(\.threshold) == [80, 95])
    }

    @Test("Zustand übersteht Speichern und Laden")
    func stateRoundTrip() throws {
        var state = AlertState()
        _ = state.alerts(for: snapshot(fiveHour: 85), thresholds: thresholds, at: now)

        var restored = try JSONDecoder().decode(AlertState.self, from: JSONEncoder().encode(state))
        #expect(restored == state)
        #expect(restored.alerts(for: snapshot(fiveHour: 85), thresholds: thresholds, at: now).isEmpty)
    }
}
