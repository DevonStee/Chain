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
        let dir = URL(fileURLWithPath: "/tmp/test", isDirectory: true)

        let appURL = ChainCommandURL.makeURL(action: .openIn, directory: dir, app: .ghostty)
        assertMenu(appURL != nil, "app URL should build")
        if let parsed = appURL.flatMap(ChainCommandURL.parse) {
            assertMenu(parsed.action == .openIn, "action should parse")
            assertMenu(parsed.app == .ghostty, "app should parse")
            assertMenu(parsed.directory.path == dir.path, "directory should parse")
        } else {
            assertMenu(false, "app URL should parse")
        }

        let mdURL = ChainCommandURL.makeURL(action: .createMarkdownFile, directory: dir)
        assertMenu(mdURL != nil, "markdown URL should build")
        if let parsed = mdURL.flatMap(ChainCommandURL.parse) {
            assertMenu(parsed.action == .createMarkdownFile, "markdown action should parse")
            assertMenu(parsed.app == nil, "markdown should have no app")
        } else {
            assertMenu(false, "markdown URL should parse")
        }

        // URL round-trip with special characters (spaces, unicode)
        let spaceDir = URL(fileURLWithPath: "/tmp/My Folder", isDirectory: true)
        let spaceURL = ChainCommandURL.makeURL(action: .openIn, directory: spaceDir, app: .vscode)
        assertMenu(spaceURL != nil, "URL with spaces should build")
        if let parsed = spaceURL.flatMap(ChainCommandURL.parse) {
            assertMenu(parsed.directory.path == spaceDir.path, "path with spaces should round-trip")
            assertMenu(parsed.app == .vscode, "app should round-trip with space path")
        } else {
            assertMenu(false, "URL with spaces should parse")
        }

        let unicodeDir = URL(fileURLWithPath: "/tmp/项目文件夹", isDirectory: true)
        let unicodeURL = ChainCommandURL.makeURL(action: .openIn, directory: unicodeDir, app: .zed)
        assertMenu(unicodeURL != nil, "URL with unicode should build")
        if let parsed = unicodeURL.flatMap(ChainCommandURL.parse) {
            assertMenu(parsed.directory.path == unicodeDir.path, "unicode path should round-trip")
            assertMenu(parsed.app == .zed, "app should round-trip with unicode path")
        } else {
            assertMenu(false, "URL with unicode should parse")
        }

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
