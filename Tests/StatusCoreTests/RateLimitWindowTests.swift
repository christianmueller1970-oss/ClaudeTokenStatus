import Foundation
import Testing
@testable import StatusCore

@Suite("Effektiver Wert und Ampel")
struct RateLimitWindowTests {
    let reset = Date(timeIntervalSince1970: 1_792_701_000)

    @Test("Vor dem Reset gilt der gemeldete Wert")
    func beforeReset() {
        let window = RateLimitWindow(usedPercentage: 42, resetsAt: reset)
        let effective = window.effective(at: reset.addingTimeInterval(-1))

        #expect(effective == EffectiveWindow(usedPercentage: 42, resetsAt: reset, isEstimated: false))
        #expect(effective.remainingPercentage == 58)
    }

    @Test("Ab dem Reset gilt das Fenster als leer und geschätzt")
    func afterReset() {
        let window = RateLimitWindow(usedPercentage: 97, resetsAt: reset)

        #expect(window.effective(at: reset) == EffectiveWindow(usedPercentage: 0, resetsAt: nil, isEstimated: true))
        #expect(window.effective(at: reset.addingTimeInterval(3_600)).remainingPercentage == 100)
    }

    @Test("Ampelstufen an den Schwellen", arguments: [
        (0.0, UsageLevel.normal),
        (69.9, .normal),
        (70, .warning),
        (89.9, .warning),
        (90, .critical),
        (100, .critical),
    ])
    func levels(percentage: Double, expected: UsageLevel) {
        #expect(UsageLevel(usedPercentage: percentage) == expected)
    }
}
