import Foundation
import Testing
@testable import StatusCore

@Suite("Statuszeile in settings.json")
struct StatusLineConfigTests {
    let bridge = "/Applications/ClaudeTokenStatus.app/Contents/MacOS/claude-status-bridge"

    @Test("Zustand: fehlende Datei, ohne statusLine, eigene und fremde Statuszeile")
    func states() throws {
        #expect(try StatusLineConfig.state(ofSettings: nil, bridgePath: bridge) == .notConfigured)
        #expect(try StatusLineConfig.state(ofSettings: Data(#"{"model":"opus"}"#.utf8), bridgePath: bridge) == .notConfigured)

        let own = Data(#"{"statusLine":{"type":"command","command":"\#(bridge)"}}"#.utf8)
        #expect(try StatusLineConfig.state(ofSettings: own, bridgePath: bridge) == .configured)

        let other = Data(#"{"statusLine":{"type":"command","command":"~/bin/mein-status.sh"}}"#.utf8)
        #expect(try StatusLineConfig.state(ofSettings: other, bridgePath: bridge) == .otherCommand("~/bin/mein-status.sh"))
    }

    @Test("Eintragen behält alle anderen Einstellungen")
    func installingKeepsOtherKeys() throws {
        let original = Data(#"{"model":"opus","permissions":{"allow":["Bash(ls:*)"]},"statusLine":{"type":"command","command":"alt"}}"#.utf8)
        let updated = try StatusLineConfig.installing(bridgePath: bridge, intoSettings: original)
        let object = try #require(try JSONSerialization.jsonObject(with: updated) as? [String: Any])

        #expect(object["model"] as? String == "opus")
        #expect((object["permissions"] as? [String: Any])?["allow"] as? [String] == ["Bash(ls:*)"])
        #expect(object["statusLine"] as? [String: String] == ["type": "command", "command": bridge])
        #expect(try StatusLineConfig.state(ofSettings: updated, bridgePath: bridge) == .configured)
    }

    @Test("Kaputtes oder falsches JSON wird nicht überschrieben")
    func refusesInvalidSettings() {
        #expect(throws: (any Error).self) { try StatusLineConfig.installing(bridgePath: bridge, intoSettings: Data("{kaputt".utf8)) }
        #expect(throws: StatusLineConfig.ConfigError.notAnObject) {
            try StatusLineConfig.installing(bridgePath: bridge, intoSettings: Data("[1,2]".utf8))
        }
    }

    @Test("Pfade mit Leerzeichen oder Hochkomma werden für die Shell maskiert")
    func shellQuoting() {
        #expect(StatusLineConfig.command(forBridgeAt: bridge) == bridge)
        #expect(StatusLineConfig.command(forBridgeAt: "/Applications/Claude Status.app/x") == "'/Applications/Claude Status.app/x'")
        #expect(StatusLineConfig.command(forBridgeAt: "/tmp/it's") == #"'/tmp/it'\''s'"#)
    }

    @Test("Installieren legt Backup an und schreibt die Datei")
    func installWritesBackup() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("StatusLineConfigTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = dir.appendingPathComponent("settings.json")
        let original = Data(#"{"model":"opus"}"#.utf8)
        try original.write(to: settings)

        let backup = try #require(try StatusLineConfig.install(
            bridgePath: bridge, settingsURL: settings, now: Date(timeIntervalSince1970: 1_792_690_000)))

        #expect(backup.lastPathComponent.hasPrefix("settings.json.bak-"))
        #expect(try Data(contentsOf: backup) == original)
        #expect(try StatusLineConfig.state(ofSettings: Data(contentsOf: settings), bridgePath: bridge) == .configured)
    }

    @Test("Ohne vorhandene Datei: kein Backup, Ordner wird angelegt")
    func installWithoutExistingFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("StatusLineConfigTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let settings = dir.appendingPathComponent(".claude/settings.json")

        #expect(try StatusLineConfig.install(bridgePath: bridge, settingsURL: settings) == nil)
        #expect(try StatusLineConfig.state(ofSettings: Data(contentsOf: settings), bridgePath: bridge) == .configured)
    }

    @Test("Kaputte Datei bleibt unverändert, kein Backup")
    func installLeavesBrokenFileAlone() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("StatusLineConfigTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = dir.appendingPathComponent("settings.json")
        try Data("{kaputt".utf8).write(to: settings)

        #expect(throws: (any Error).self) { try StatusLineConfig.install(bridgePath: bridge, settingsURL: settings) }
        #expect(try Data(contentsOf: settings) == Data("{kaputt".utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == ["settings.json"])
    }
}
