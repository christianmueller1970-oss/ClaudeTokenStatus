import StatusCore
import SwiftUI

/// Inhalt beim Klick auf das Menüleisten-Icon.
struct StatusPopoverView: View {
    let model: StatusModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(alignment: .leading, spacing: 14) {
                Text("Claude-Abo")
                    .font(.headline)

                if let snapshot = model.snapshot {
                    LimitRow(title: "5-Stunden-Fenster", window: snapshot.fiveHour?.effective(at: context.date))
                    LimitRow(title: "Wochenlimit", window: snapshot.sevenDay?.effective(at: context.date))
                    Divider()
                    SessionInfo(snapshot: snapshot)
                    Divider()
                    Freshness(snapshot: snapshot, now: context.date)
                } else {
                    Text("Noch keine Daten. Ist die Statuszeile in Claude Code eingerichtet und lief seither eine Session?")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let readError = model.readError {
                    Label(readError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Button("Einstellungen …") {
                        // Ohne Dock-Icon muss die App aktiviert werden, sonst öffnet das Fenster im Hintergrund
                        NSApplication.shared.activate()
                        openSettings()
                    }
                    .keyboardShortcut(",")
                    Spacer()
                    Button("Beenden") { NSApplication.shared.terminate(nil) }
                        .keyboardShortcut("q")
                }
            }
            .padding(16)
            .frame(width: 300)
        }
    }
}

private struct LimitRow: View {
    let title: String
    let window: EffectiveWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(percentText)
                    .monospacedDigit()
                    .foregroundStyle(window == nil ? .secondary : .primary)
            }
            ProgressView(value: min((window?.usedPercentage ?? 0) / 100, 1))
                .tint(window?.level.color ?? .secondary)
            Text(resetText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var percentText: String {
        guard let window else { return "–" }
        return "\(Int(window.usedPercentage.rounded())) % verbraucht"
    }

    private var resetText: String {
        guard let window else { return "Noch kein Wert von Claude Code" }
        if window.isEstimated { return "Zurückgesetzt (geschätzt, bis neue Werte kommen)" }
        guard let resetsAt = window.resetsAt else { return "" }
        let time = resetsAt.formatted(date: .omitted, time: .shortened)
        let day = Calendar.current.isDateInToday(resetsAt) ? "" : resetsAt.formatted(.dateTime.weekday(.abbreviated)) + " "
        return "Reset in \(DurationText.short(resetsAt.timeIntervalSinceNow)) (\(day)\(time))"
    }
}

private struct SessionInfo: View {
    let snapshot: ClaudeStatusSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Letzte Session")
                .font(.subheadline.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 2) {
                GridRow {
                    Text("Modell").foregroundStyle(.secondary)
                    Text(snapshot.modelName ?? "–")
                }
                GridRow {
                    Text("Kontext").foregroundStyle(.secondary)
                    Text(snapshot.contextUsedPercentage.map { "\(Int($0.rounded())) %" } ?? "–")
                }
                GridRow {
                    Text("Kosten").foregroundStyle(.secondary)
                    Text(snapshot.sessionCostUSD.map { String(format: "%.2f $ (Listenpreis)", $0) } ?? "–")
                }
            }
            .font(.callout)
        }
    }
}

private struct Freshness: View {
    let snapshot: ClaudeStatusSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Aktualisiert \(DurationText.ago(snapshot.age(at: now)))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if snapshot.isStale(at: now) {
                Label("Wert ist veraltet. Neue Werte kommen erst mit der nächsten Antwort in Claude Code.",
                      systemImage: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
