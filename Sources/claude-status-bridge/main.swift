// Statuszeilen-Command für Claude Code: liest das JSON von stdin,
// aktualisiert status.json für die Menüleisten-App und gibt die Statuszeile aus.
// Beendet sich immer mit 0, damit die Statuszeile von Claude Code nie bricht.
import Foundation
import StatusCore

// Pfad für Tests überschreibbar
let url = ProcessInfo.processInfo.environment["CLAUDE_TOKEN_STATUS_FILE"]
    .map { URL(fileURLWithPath: $0) } ?? StatusFile.defaultURL

let input = FileHandle.standardInput.readDataToEndOfFile()
// Fehlende oder kaputte status.json zählt als «kein Vorgänger»
let previous = try? StatusFile.read(from: url)
let result = StatusBridge.process(input: input, previous: previous, now: Date())

if let snapshot = result.snapshot {
    do {
        try StatusFile.write(snapshot, to: url)
    } catch {
        FileHandle.standardError.write(Data("claude-status-bridge: \(error.localizedDescription)\n".utf8))
    }
}

print(result.line)
