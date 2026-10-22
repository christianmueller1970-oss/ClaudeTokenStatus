import ServiceManagement
import StatusCore
import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(AppSettings.warningThreshold) private var warningThreshold = 80.0
    @AppStorage(AppSettings.criticalThreshold) private var criticalThreshold = 95.0

    var body: some View {
        Form {
            Section("Mitteilungen") {
                Toggle("Bei hohem Verbrauch benachrichtigen", isOn: $notificationsEnabled)
                Stepper("Warnung ab \(Int(warningThreshold)) %", value: $warningThreshold, in: 50...95, step: 5)
                    .disabled(!notificationsEnabled)
                Stepper("Kritisch ab \(Int(criticalThreshold)) %", value: $criticalThreshold, in: 55...100, step: 5)
                    .disabled(!notificationsEnabled)
                Text("Jede Schwelle meldet sich pro Limit-Fenster nur einmal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Start") {
                LoginItemToggle()
            }
            Section("Claude Code") {
                StatusLineSetupView()
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct LoginItemToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled
    @State private var error: String?

    var body: some View {
        Toggle("Bei Anmeldung starten", isOn: Binding(get: { isEnabled }, set: update))
        if !AppSettings.isInstalledInApplications {
            Text("Tipp: Die App zuerst nach /Applications verschieben, sonst zeigt der Login-Start auf diesen Ort.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if let error {
            Text(error).font(.caption).foregroundStyle(.red)
        }
    }

    private func update(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}

private struct StatusLineSetupView: View {
    @State private var state: Result<StatusLineConfig.State, Error>?
    @State private var lastBackup: URL?
    @State private var installError: String?
    @State private var confirmReplace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let bridgePath = AppSettings.bridgePath {
                content(bridgePath: bridgePath)
            } else {
                Label("Bridge fehlt im App-Bundle.", systemImage: "xmark.octagon")
                    .foregroundStyle(.red)
            }
            if let lastBackup {
                Text("Backup: \(lastBackup.path)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            if let installError {
                Text(installError).font(.caption).foregroundStyle(.red)
            }
        }
        .onAppear(perform: refresh)
    }

    @ViewBuilder
    private func content(bridgePath: String) -> some View {
        switch state {
        case .success(.configured):
            Label("Statuszeile ist eingerichtet.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .success(.notConfigured):
            Text("Claude Code liefert die Limits nur an eine Statuszeile. Sie wird in ~/.claude/settings.json eingetragen, vorher gibt es ein Backup.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            Button("Statuszeile einrichten") { install(bridgePath) }
        case .success(.otherCommand(let command)):
            Text("Eingetragen ist bereits eine andere Statuszeile:")
                .font(.callout)
            Text(command)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            Button("Ersetzen …") { confirmReplace = true }
                .confirmationDialog("Bestehende Statuszeile ersetzen?", isPresented: $confirmReplace) {
                    Button("Ersetzen") { install(bridgePath) }
                } message: {
                    Text("Die bisherige Statuszeile wird nicht mehr angezeigt. Ein Backup von settings.json wird angelegt.")
                }
        case .failure(let error):
            Text("settings.json nicht lesbar: \(error.localizedDescription)")
                .font(.callout)
                .foregroundStyle(.red)
        case nil:
            EmptyView()
        }
        if !AppSettings.isInstalledInApplications {
            Text("Hinweis: Die App liegt nicht in /Applications. Nach dem Verschieben die Statuszeile neu einrichten.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func refresh() {
        guard let bridgePath = AppSettings.bridgePath else { return }
        let url = StatusLineConfig.defaultSettingsURL
        state = Result {
            let data = FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
            return try StatusLineConfig.state(ofSettings: data, bridgePath: bridgePath)
        }
    }

    private func install(_ bridgePath: String) {
        do {
            lastBackup = try StatusLineConfig.install(bridgePath: bridgePath)
            installError = nil
        } catch {
            installError = "Einrichten fehlgeschlagen: \(error.localizedDescription)"
        }
        refresh()
    }
}
