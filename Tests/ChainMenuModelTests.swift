import Foundation

func assertMenu(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct ChainMenuModelTests {
    static func main() {
        // Menu titles
        assertMenu(ChainSupportedApp.terminal.menuTitle == "Open in Terminal", "Terminal title")
        assertMenu(ChainSupportedApp.iterm2.menuTitle == "Open in iTerm2", "iTerm2 title")
        assertMenu(ChainSupportedApp.kitty.menuTitle == "Open in kitty", "kitty title")
        assertMenu(ChainSupportedApp.ghostty.menuTitle == "Open in Ghostty", "Ghostty title")
        assertMenu(ChainSupportedApp.otty.menuTitle == "Open in Otty", "Otty title")
        assertMenu(ChainSupportedApp.customCommandTerminals.contains(.otty), "Otty should run custom commands")
        assertMenu(ChainSupportedApp.vscode.menuTitle == "Open in VS Code", "VS Code title")
        assertMenu(ChainSupportedApp.cursor.menuTitle == "Open in Cursor", "Cursor title")
        assertMenu(ChainSupportedApp.obsidian.menuTitle == "Open Obsidian", "Obsidian title")
        assertMenu(ChainAppCatalog.newMarkdownTitle == "New Note", "markdown title")
        assertMenu(ChainAppCatalog.launchAtLoginTitle == "Launch at Login", "launch at login title")
        assertMenu(ChainAppCatalog.restartFinderExtensionTitle == "Not Showing?", "reload title")
        assertMenu(ChainAppCatalog.quitTitle == "Quit", "quit title")

        // App ordering
        assertMenu(ChainSupportedApp.allCases.first == .terminal, "first case should be terminal")
        assertMenu(ChainSupportedApp.allCases.last == .obsidian, "last case should be obsidian")
        assertMenu(ChainSupportedApp.allCases.count == 31, "should have 31 supported apps")

        // URL scheme round-trip
        ChainSettings.ensureCommandNonce()
        let dir = URL(fileURLWithPath: "/tmp/test", isDirectory: true)

        func roundTrip(_ command: ChainCommand) -> ChainCommand? {
            ChainCommandURL.makeURL(command).flatMap(ChainCommandURL.parse)
        }

        for command in [
            ChainCommand.openIn(.ghostty, directory: dir),
            .createMarkdownFile(directory: dir),
            .runCustomCommand(directory: dir),
            // Special characters (spaces, unicode)
            .openIn(.vscode, directory: URL(fileURLWithPath: "/tmp/My Folder", isDirectory: true)),
            .openIn(.zed, directory: URL(fileURLWithPath: "/tmp/项目文件夹", isDirectory: true)),
        ] {
            assertMenu(roundTrip(command) == command, "\(command) should round-trip")
        }

        // An openIn URL must name a valid app; the type can no longer represent one without it.
        if let valid = ChainCommandURL.makeURL(.openIn(.ghostty, directory: dir)),
           var components = URLComponents(url: valid, resolvingAgainstBaseURL: false) {
            components.queryItems?.removeAll { $0.name == "app" }
            assertMenu(components.url.flatMap(ChainCommandURL.parse) == nil, "openIn without an app should be rejected")
        } else {
            assertMenu(false, "openIn URL should build")
        }

        if let finishSetup = ChainCommandURL.finishSetupURL {
            assertMenu(ChainCommandURL.parse(finishSetup) == nil, "finish-setup URL should carry no command")
        } else {
            assertMenu(false, "finish-setup URL should build")
        }

        // Selection keeps apps that are temporarily unavailable
        let start = ChainAppSelection(active: [.terminal, .zed], unavailable: [])
        let unplugged = start.reconciled(installed: [.terminal], maxCount: 3)
        assertMenu(unplugged.active == [.terminal], "unavailable app should leave the active set")
        assertMenu(unplugged.unavailable == [.zed], "unavailable app should stay remembered")
        assertMenu(unplugged.persisted == [.terminal, .zed], "remembered app should still be stored")
        let replugged = unplugged.reconciled(installed: [.terminal, .zed], maxCount: 3)
        assertMenu(replugged == start, "returning app should be selected again")

        let full = ChainAppSelection(active: [.terminal, .kitty, .warp], unavailable: [.zed])
            .reconciled(installed: [.terminal, .kitty, .warp, .zed], maxCount: 3)
        assertMenu(full.active == [.terminal, .kitty, .warp], "returning app should not displace current choices")

        let noneLeft = ChainAppSelection(active: [.zed], unavailable: [])
            .reconciled(installed: [.terminal], maxCount: 3)
        assertMenu(noneLeft.active == [.terminal] && noneLeft.unavailable == [.zed], "should fall back but keep remembering")

        // Custom command rule
        assertMenu(!ChainSettings.isRunnableCommand(""), "empty command should not run")
        assertMenu(!ChainSettings.isRunnableCommand("  \n"), "blank command should not run")
        assertMenu(ChainSettings.isRunnableCommand("ls"), "real command should run")

        // ChainSupportedApp raw value round-trip (same encoding ChainSettings uses)
        for app in ChainSupportedApp.allCases {
            let raw = app.rawValue
            assertMenu(ChainSupportedApp(rawValue: raw) == app, "\(app) raw value round-trip")
        }

        // Simulated settings encode/decode
        let selected: [ChainSupportedApp] = [.ghostty, .vscode, .cursor]
        let encoded = selected.map(\.rawValue)
        let decoded = encoded.compactMap { ChainSupportedApp(rawValue: $0) }
        assertMenu(decoded == selected, "settings encode/decode should preserve order and values")

        // Empty decode should fallback
        let emptyDecoded = [String]().compactMap { ChainSupportedApp(rawValue: $0) }
        assertMenu(emptyDecoded.isEmpty, "empty raw values should decode to empty array")

        // maxSelection constant
        assertMenu(ChainSettings.maxSelection == 3, "max selection should be 3")

        print("Chain menu model tests passed")
    }
}
