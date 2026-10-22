// Statuszeilen-Command für Claude Code: liest das JSON von stdin,
// aktualisiert status.json für die Menüleisten-App und gibt die Statuszeile aus.
// Beendet sich immer mit 0, damit die Statuszeile von Claude Code nie bricht.
import Foundation
import StatusCore

// Pfad für Tests überschreibbar
let url = ProcessInfo.processInfo.environment["CLAUDE_TOKEN_STATUS_FILE"]
    .map { URL(fileURLWithPath: $0) } ?? StatusFile.defaultURL

let input = FileHandle.standardInput.readDataToEndOfFile()
var result: StatusBridge.Result?

do {
    try StatusFile.update(at: url) { previous in
        let processed = StatusBridge.process(input: input, previous: previous, now: Date())
        result = processed
        return processed.snapshot
    }
} catch {
    FileHandle.standardError.write(Data("claude-status-bridge: \(error.localizedDescription)\n".utf8))
}

// Auch wenn status.json nicht erreichbar war, soll die Statuszeile etwas zeigen
print((result ?? StatusBridge.process(input: input, previous: nil, now: Date())).line)
