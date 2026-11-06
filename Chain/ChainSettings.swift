import Foundation
import Security

enum ChainSettings {
    static let maxSelection = 3
    private static let suiteName = "com.lursetawet.chain"
    private static let selectedAppsKey = "selectedApps"
    private static let customCommandTextKey = "customCommandText"
    private static let customCommandTerminalKey = "customCommandTerminal"
    private static let customCommandEnabledKey = "customCommandEnabled"
    private static let customCommandLabelKey = "customCommandLabel"
    private static let hasSeenOnboardingKey = "hasSeenOnboarding"
    private static let commandNonceKey = "commandNonce"

    /// The main app owns these settings. The FinderSync extension reads them through its
    /// read-only sandbox exception. UserDefaults rejects an app's own bundle ID as a suite name.
    private static let sharedDefaults: UserDefaults? = Bundle.main.bundleIdentifier == suiteName
        ? UserDefaults.standard
        : UserDefaults(suiteName: suiteName)

    /// Shared secret between main app and FinderSync extension. Used to reject
    /// `com.lursetawet.chain://` URLs forged by webpages or other apps.
    /// The main app creates it at launch; the extension cannot write it.
    static var commandNonce: String {
        if let existing = sharedDefaults?.string(forKey: commandNonceKey), !existing.isEmpty {
            return existing
        }
        var bytes = [UInt8](repeating: 0, count: 24)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let nonce = Data(bytes).base64EncodedString()
        sharedDefaults?.set(nonce, forKey: commandNonceKey)
        return nonce
    }

    static var selectedApps: [ChainSupportedApp] {
        guard let defaults = sharedDefaults,
              let rawValues = defaults.stringArray(forKey: selectedAppsKey) else {
            return [.terminal]
        }
        let apps = rawValues.compactMap { ChainSupportedApp(rawValue: $0) }
        return apps.isEmpty ? [.terminal] : apps
    }

    static func setSelectedApps(_ apps: [ChainSupportedApp]) {
        guard let defaults = sharedDefaults else { return }
        let rawValues = apps.map(\.rawValue)
        defaults.set(rawValues, forKey: selectedAppsKey)
    }

    static var customCommandText: String {
        sharedDefaults?.string(forKey: customCommandTextKey) ?? ""
    }

    static func setCustomCommandText(_ text: String) {
        sharedDefaults?.set(text, forKey: customCommandTextKey)
    }

    static var customCommandTerminal: ChainSupportedApp {
        guard let raw = sharedDefaults?.string(forKey: customCommandTerminalKey),
              let app = ChainSupportedApp(rawValue: raw),
              ChainSupportedApp.customCommandTerminals.contains(app) else {
            return ChainSupportedApp.customCommandTerminals.first ?? .terminal
        }
        return app
    }

    static func setCustomCommandTerminal(_ app: ChainSupportedApp) {
        sharedDefaults?.set(app.rawValue, forKey: customCommandTerminalKey)
    }

    static var customCommandEnabled: Bool {
        sharedDefaults?.bool(forKey: customCommandEnabledKey) ?? false
    }

    static func setCustomCommandEnabled(_ enabled: Bool) {
        sharedDefaults?.set(enabled, forKey: customCommandEnabledKey)
    }

    static var customCommandLabel: String {
        sharedDefaults?.string(forKey: customCommandLabelKey) ?? ""
    }

    static func setCustomCommandLabel(_ label: String) {
        sharedDefaults?.set(label, forKey: customCommandLabelKey)
    }

    static var hasSeenOnboarding: Bool {
        sharedDefaults?.bool(forKey: hasSeenOnboardingKey) ?? false
    }

    static func markOnboardingSeen() {
        sharedDefaults?.set(true, forKey: hasSeenOnboardingKey)
    }

    static var effectiveCustomCommandLabel: String {
        let label = customCommandLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        return label.isEmpty ? ChainAppCatalog.customCommandTitle : label
    }
}
