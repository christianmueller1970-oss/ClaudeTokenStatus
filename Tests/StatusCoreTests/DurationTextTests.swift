import Foundation
import Testing
@testable import StatusCore

@Suite("Zeitangaben")
struct DurationTextTests {
    @Test("Kurzform mit den zwei grössten Einheiten", arguments: [
        (0, "0 min"),
        (59, "0 min"),
        (60, "1 min"),
        (14 * 60, "14 min"),
        (2 * 3_600, "2 h"),
        (2 * 3_600 + 14 * 60 + 59, "2 h 14 min"),
        (24 * 3_600, "1 T"),
        (46 * 3_600 + 30 * 60, "1 T 22 h"),
        (-120, "0 min"),
    ] as [(TimeInterval, String)])
    func short(interval: TimeInterval, expected: String) {
        #expect(DurationText.short(interval) == expected)
    }

    @Test("Alter des Werts")
    func ago() {
        #expect(DurationText.ago(10) == "gerade eben")
        #expect(DurationText.ago(3 * 60) == "vor 3 min")
        #expect(DurationText.ago(2 * 3_600) == "vor 2 h")
    }
}
