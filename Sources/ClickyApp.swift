import SwiftUI
import AppKit

@main
struct ClickyApp: App {
    @StateObject private var model = ClickerModel.shared

    var body: some Scene {
        Window("Clicky", id: "main") {
            ContentView(model: model)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.isRunning ? "cursorarrow.click.2" : "cursorarrow.click")
        }
    }
}

struct MenuContent: View {
    @ObservedObject var model: ClickerModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(model.isBusy ? "Stop Clicking" : "Start Clicking (3s delay)") {
            model.toggle(countdown: true)
        }
        Text("\(model.clicks.formatted()) clicks this run")
        Divider()
        Button("Show Clicky") {
            openWindow(id: "main")
            NSApp.activate()
        }
        Button("Quit Clicky") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
