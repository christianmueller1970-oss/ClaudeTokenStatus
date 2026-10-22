import Foundation
import Testing
@testable import StatusCore

extension AlertState {
    /// Testhilfe: alle fälligen Mitteilungen gelten als erfolgreich zugestellt
    mutating func deliverAll(for snapshot: ClaudeStatusSnapshot, thresholds: [Double], at now: Date) -> [ThresholdAlert] {
        let alerts = pendingAlerts(for: snapshot, thresholds: thresholds, at: now)
        alerts.forEach { markNotified($0) }
        return alerts
    }
}

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
        #expect(state.deliverAll(for: snapshot(fiveHour: 79), thresholds: thresholds, at: now).isEmpty)
    }

    @Test("Jede Schwelle meldet pro Fenster genau einmal")
    func eachThresholdOnce() {
        var state = AlertState()

        let first = state.deliverAll(for: snapshot(fiveHour: 80), thresholds: thresholds, at: now)
        #expect(first.map(\.threshold) == [80])
        #expect(first.first?.kind == .fiveHour)
        #expect(state.deliverAll(for: snapshot(fiveHour: 88), thresholds: thresholds, at: now).isEmpty)
        #expect(state.deliverAll(for: snapshot(fiveHour: 96), thresholds: thresholds, at: now).map(\.threshold) == [95])
        #expect(state.deliverAll(for: snapshot(fiveHour: 99), thresholds: thresholds, at: now).isEmpty)
    }

    @Test("Sprung über beide Schwellen meldet nur die höchste")
    func jumpReportsHighestOnly() {
        var state = AlertState()
        let alerts = state.deliverAll(for: snapshot(fiveHour: 97), thresholds: thresholds, at: now)
        #expect(alerts.map(\.threshold) == [95])
        #expect(state.deliverAll(for: snapshot(fiveHour: 97), thresholds: thresholds, at: now).isEmpty)
    }

    @Test("Neues Fenster meldet wieder von vorn")
    func newWindowResets() {
        var state = AlertState()
        _ = state.deliverAll(for: snapshot(fiveHour: 96), thresholds: thresholds, at: now)

        let nextReset = reset.addingTimeInterval(5 * 3_600)
        let alerts = state.deliverAll(for: snapshot(fiveHour: 81, reset: nextReset), thresholds: thresholds, at: now)
        #expect(alerts.map(\.threshold) == [80])
    }

    @Test("Abgelaufenes Fenster meldet nichts")
    func expiredWindowIsSilent() {
        var state = AlertState()
        #expect(state.deliverAll(for: snapshot(fiveHour: 99), thresholds: thresholds, at: reset).isEmpty)
    }

    @Test("Beide Fenster werden unabhängig gemeldet")
    func bothKinds() {
        var state = AlertState()
        let alerts = state.deliverAll(for: snapshot(fiveHour: 85, sevenDay: 95), thresholds: thresholds, at: now)
        #expect(alerts.map(\.kind) == [.fiveHour, .sevenDay])
        #expect(alerts.map(\.threshold) == [80, 95])
    }

    @Test("Nicht zugestellte Mitteilung bleibt fällig (z. B. Erlaubnis verweigert)")
    func undeliveredStaysPending() {
        var state = AlertState()
        let pending = state.pendingAlerts(for: snapshot(fiveHour: 85), thresholds: thresholds, at: now)
        #expect(pending.map(\.threshold) == [80])
        // Nicht markiert: beim nächsten Mal wieder fällig
        #expect(state.pendingAlerts(for: snapshot(fiveHour: 85), thresholds: thresholds, at: now) == pending)

        state.markNotified(pending[0])
        #expect(state.pendingAlerts(for: snapshot(fiveHour: 85), thresholds: thresholds, at: now).isEmpty)
    }

    @Test("Spät zugestellte tiefere Schwelle überschreibt keine höhere")
    func markNotifiedKeepsHigherThreshold() {
        var state = AlertState()
        let low = ThresholdAlert(kind: .fiveHour, threshold: 80, usedPercentage: 81, resetsAt: reset)
        let high = ThresholdAlert(kind: .fiveHour, threshold: 95, usedPercentage: 96, resetsAt: reset)
        state.markNotified(high)
        state.markNotified(low)
        #expect(state.pendingAlerts(for: snapshot(fiveHour: 96), thresholds: thresholds, at: now).isEmpty)

        // Ebenso darf ein älteres Fenster ein neueres nicht verdrängen
        let nextReset = reset.addingTimeInterval(5 * 3_600)
        state.markNotified(ThresholdAlert(kind: .fiveHour, threshold: 80, usedPercentage: 82, resetsAt: nextReset))
        state.markNotified(high)
        #expect(state.pendingAlerts(for: snapshot(fiveHour: 82, reset: nextReset), thresholds: thresholds, at: now).isEmpty)
    }

    @Test("Zustand übersteht Speichern und Laden")
    func stateRoundTrip() throws {
        var state = AlertState()
        _ = state.deliverAll(for: snapshot(fiveHour: 85), thresholds: thresholds, at: now)

        var restored = try JSONDecoder().decode(AlertState.self, from: JSONEncoder().encode(state))
        #expect(restored == state)
        #expect(restored.deliverAll(for: snapshot(fiveHour: 85), thresholds: thresholds, at: now).isEmpty)
    }
}
