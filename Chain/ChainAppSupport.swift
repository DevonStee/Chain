import Foundation
#if canImport(AppKit)
import AppKit
#endif

enum ChainSupportedApp: String, CaseIterable, Codable {
    // Terminals
    case terminal
    case iterm2
    case hyper
    case alacritty
    case kitty
    case warp
    case wezterm
    case tabby
    case ghostty
    case otty
    // Editors
    case xcode
    case vscode
    case vscodeInsiders
    case sublimeText
    case vscodium
    case bbedit
    case textMate
    case cotEditor
    case macVim
    case clion
    case goland
    case intellij
    case phpStorm
    case pycharm
    case rubyMine
    case webStorm
    case androidStudio
    case nova
    case zed
    case cursor
    case obsidian

    var bundleIdentifier: String {
        switch self {
        // Terminals
        case .terminal: return "com.apple.Terminal"
        case .iterm2: return "com.googlecode.iterm2"
        case .hyper: return "co.zeit.hyper"
        case .alacritty: return "org.alacritty"
        case .kitty: return "net.kovidgoyal.kitty"
        case .warp: return "dev.warp.Warp-Stable"
        case .wezterm: return "com.github.wez.wezterm"
        case .tabby: return "org.tabby"
        case .ghostty: return "com.mitchellh.ghostty"
        case .otty: return "io.appmakes.otty"
        // Editors
        case .xcode: return "com.apple.dt.Xcode"
        case .vscode: return "com.microsoft.VSCode"
        case .vscodeInsiders: return "com.microsoft.VSCodeInsiders"
        case .sublimeText: return "com.sublimetext.4"
        case .vscodium: return "com.vscodium"
        case .bbedit: return "com.barebones.bbedit"
        case .textMate: return "com.macromates.TextMate"
        case .cotEditor: return "com.coteditor.CotEditor"
        case .macVim: return "org.vim.MacVim"
        case .clion: return "com.jetbrains.CLion"
        case .goland: return "com.jetbrains.goland"
        case .intellij: return "com.jetbrains.intellij"
        case .phpStorm: return "com.jetbrains.PhpStorm"
        case .pycharm: return "com.jetbrains.pycharm"
        case .rubyMine: return "com.jetbrains.rubymine"
        case .webStorm: return "com.jetbrains.WebStorm"
        case .androidStudio: return "com.google.android.studio"
        case .nova: return "com.panic.Nova"
        case .zed: return "dev.zed.Zed"
        case .cursor: return "com.todesktop.230313mzl4w4u92"
        case .obsidian: return "md.obsidian"
        }
    }

    var applicationName: String {
        switch self {
        case .terminal: return "Terminal"
        case .iterm2: return "iTerm2"
        case .hyper: return "Hyper"
        case .alacritty: return "Alacritty"
        case .kitty: return "kitty"
        case .warp: return "Warp"
        case .wezterm: return "WezTerm"
        case .tabby: return "Tabby"
        case .ghostty: return "Ghostty"
        case .otty: return "Otty"
        case .xcode: return "Xcode"
        case .vscode: return "VS Code"
        case .vscodeInsiders: return "VS Code Insiders"
        case .sublimeText: return "Sublime Text"
        case .vscodium: return "VSCodium"
        case .bbedit: return "BBEdit"
        case .textMate: return "TextMate"
        case .cotEditor: return "CotEditor"
        case .macVim: return "MacVim"
        case .clion: return "CLion"
        case .goland: return "GoLand"
        case .intellij: return "IntelliJ IDEA"
        case .phpStorm: return "PhpStorm"
        case .pycharm: return "PyCharm"
        case .rubyMine: return "RubyMine"
        case .webStorm: return "WebStorm"
        case .androidStudio: return "Android Studio"
        case .nova: return "Nova"
        case .zed: return "Zed"
        case .cursor: return "Cursor"
        case .obsidian: return "Obsidian"
        }
    }

    var menuTitle: String {
        switch self {
        case .obsidian:
            return "Open \(applicationName)"
        default:
            return "Open in \(applicationName)"
        }
    }

    var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    // Ghostty omitted: its -e flag triggers a user confirmation prompt by design.
    static let customCommandTerminals: [ChainSupportedApp] = [
        .terminal, .iterm2, .otty, .kitty, .alacritty, .wezterm
    ]
}

/// One request from the Finder extension. Only `openIn` carries an app.
enum ChainCommand: Equatable {
    case openIn(ChainSupportedApp, directory: URL)
    case createMarkdownFile(directory: URL)
    case runCustomCommand(directory: URL)
}

enum ChainCommandURL {
    private enum Action: String, CaseIterable {
        case openIn
        case createMarkdownFile
        case runCustomCommand
    }

    // Reverse-DNS scheme: plain "chain" collides with other apps (e.g. V2Box claims chain:).
    private static let scheme = "com.lursetawet.chain"
    private static let nonceKey = "nonce"

    /// Launches the main app so it can create the nonce. It carries no command.
    static var finishSetupURL: URL? { URL(string: "\(scheme)://finishSetup") }

    /// Nil until the main app has created the nonce.
    static func makeURL(_ command: ChainCommand) -> URL? {
        guard let nonce = ChainSettings.commandNonce else { return nil }
        let action: Action
        let directory: URL
        var app: ChainSupportedApp?
        switch command {
        case .openIn(let target, let commandDirectory):
            (action, directory, app) = (.openIn, commandDirectory, target)
        case .createMarkdownFile(let commandDirectory):
            (action, directory) = (.createMarkdownFile, commandDirectory)
        case .runCustomCommand(let commandDirectory):
            (action, directory) = (.runCustomCommand, commandDirectory)
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = action.rawValue
        var items: [URLQueryItem] = [
            URLQueryItem(name: "path", value: directory.path),
            URLQueryItem(name: nonceKey, value: nonce),
        ]
        if let app {
            items.append(URLQueryItem(name: "app", value: app.rawValue))
        }
        components.queryItems = items
        return components.url
    }

    static func parse(_ url: URL) -> ChainCommand? {
        guard url.scheme == scheme,
              let host = url.host else {
            return nil
        }
        // URL hosts are case-insensitive per RFC 3986; Foundation lowercases them on macOS 15+
        let hostLower = host.lowercased()
        guard let action = Action.allCases.first(where: { $0.rawValue.lowercased() == hostLower }),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let path = components.queryItems?.first(where: { $0.name == "path" })?.value else {
            return nil
        }
        // Reject URLs without a matching nonce — these come from webpages or other
        // apps that don't know the shared secret.
        let providedNonce = components.queryItems?.first(where: { $0.name == nonceKey })?.value
        guard let expectedNonce = ChainSettings.commandNonce, providedNonce == expectedNonce else {
            return nil
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        switch action {
        case .openIn:
            let appRaw = components.queryItems?.first(where: { $0.name == "app" })?.value
            guard let app = appRaw.flatMap({ ChainSupportedApp(rawValue: $0) }) else { return nil }
            return .openIn(app, directory: directory)
        case .createMarkdownFile:
            return .createMarkdownFile(directory: directory)
        case .runCustomCommand:
            return .runCustomCommand(directory: directory)
        }
    }
}

/// The user's "Open In" choices. Apps that are not installed right now stay remembered,
/// so an app on an unplugged drive comes back when the drive does.
struct ChainAppSelection: Equatable {
    var active: Set<ChainSupportedApp>
    var unavailable: Set<ChainSupportedApp>

    /// In enum order, which is the order the menu shows.
    var persisted: [ChainSupportedApp] {
        ChainSupportedApp.allCases.filter { active.contains($0) || unavailable.contains($0) }
    }

    func reconciled(installed: [ChainSupportedApp], maxCount: Int) -> ChainAppSelection {
        let installedSet = Set(installed)
        var nextActive = active.intersection(installedSet)
        // Current choices keep their slots; a returning app only takes a free one.
        for app in installed where unavailable.contains(app) && nextActive.count < maxCount {
            nextActive.insert(app)
        }
        let nextUnavailable = active.union(unavailable).subtracting(installedSet)
        if nextActive.isEmpty, let first = installed.first {
            nextActive = [first]
        }
        return ChainAppSelection(active: nextActive, unavailable: nextUnavailable)
    }
}

enum ChainAppCatalog {
    static let newMarkdownTitle = "New Note"
    static let launchAtLoginTitle = "Launch at Login"
    static let launchAtLoginApprovalTitle = "Allow in Login Items…"
    static let finishSetupTitle = "Open Chain to Finish Setup"
    static let restartFinderExtensionTitle = "Not Showing?"
    static let quitTitle = "Quit"
    static let customCommandTitle = "Custom Command"
    static let customCommandSettingsHint = "Empty command disables this feature"
}
