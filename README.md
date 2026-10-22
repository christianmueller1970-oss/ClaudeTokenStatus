# ClaudeTokenStatus

Menüleisten-App für macOS, die den Verbrauch der Claude-Abo-Limits (Pro/Max) anzeigt:
5-Stunden-Fenster und Wochenlimit, jeweils mit Reset-Countdown.

## Funktionsweise

```
Claude Code ──stdin JSON──▶ claude-status-bridge ──atomar──▶ status.json ──▶ Menüleisten-App
```

- Claude Code übergibt bei jeder Aktualisierung der Statuszeile ein JSON mit `rate_limits`
  ([Doku](https://code.claude.com/docs/en/statusline)).
- `claude-status-bridge` schreibt daraus `~/Library/Application Support/ClaudeTokenStatus/status.json`
  und gibt `5h 42% · 7d 18% · ctx 31%` als Statuszeile aus.
- Die App beobachtet die Datei per Kernel-Event, ohne Polling und ohne Netzwerkzugriff.

Werte kommen nur, solange eine Claude-Code-Session läuft. Nutzung über claude.ai fliesst ins
Limit ein, erscheint aber erst mit der nächsten Antwort in Claude Code.

## Bauen

Voraussetzungen: Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

```sh
swift test                      # StatusCore-Tests
swift build -c release          # Bridge: .build/release/claude-status-bridge
xcodegen generate               # ClaudeTokenStatus.xcodeproj aus project.yml
xcodebuild -project ClaudeTokenStatus.xcodeproj -scheme ClaudeTokenStatus \
  -configuration Debug -derivedDataPath .build/xcode build
open .build/xcode/Build/Products/Debug/ClaudeTokenStatus.app
```

## Statuszeile einrichten

In `~/.claude/settings.json` (vorher Backup):

```json
"statusLine": { "type": "command", "command": "/Pfad/zu/claude-status-bridge" }
```
