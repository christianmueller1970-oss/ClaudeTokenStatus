import StatusCore
import SwiftUI

@main
struct ClaudeTokenStatusApp: App {
    @State private var model = StatusModel()

    var body: some Scene {
        MenuBarExtra {
            StatusPopoverView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
