import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ChainSettings.ensureCommandNonce()
        guard !ChainSettings.hasSeenOnboarding else { return }
        // Marked only on success, so a failed registration retries at the next launch.
        Task {
            if await ChainMaintenance.registerFinderExtension() {
                ChainSettings.markOnboardingSeen()
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let command = ChainCommandURL.parse(url) else {
                // The URL carries the nonce and a user path, so log only its action.
                NSLog("Chain: ignored invalid or unauthorized command: %@", url.host ?? "unknown")
                continue
            }
            CustomCommandPanelController.shared.close()
            switch command {
            case .openIn(let app, let directory):
                ChainCommandExecutor.openApp(app, in: directory)
            case .createMarkdownFile(let directory):
                ChainCommandExecutor.createMarkdownFile(in: directory)
            case .runCustomCommand(let directory):
                CustomCommandRunner.run(in: directory)
            }
        }
    }
}

@main
struct ChainApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .labelStyle(.titleAndIcon)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
    }
}
