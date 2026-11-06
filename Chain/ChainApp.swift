import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = ChainSettings.commandNonce
        guard !ChainSettings.hasSeenOnboarding else { return }
        ChainMaintenance.restartFinderExtension()
        ChainSettings.markOnboardingSeen()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        CustomCommandPanelController.shared.close()
        for url in urls {
            guard let (action, directory, app) = ChainCommandURL.parse(url) else {
                // The URL carries the nonce and a user path, so log only its action.
                NSLog("Chain: ignored invalid or unauthorized command: %@", url.host ?? "unknown")
                continue
            }
            switch action {
            case .openIn:
                guard let app else { continue }
                ChainCommandExecutor.openApp(app, in: directory)
            case .createMarkdownFile:
                ChainCommandExecutor.createMarkdownFile(in: directory)
            case .runCustomCommand:
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
