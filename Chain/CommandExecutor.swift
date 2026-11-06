import AppKit

enum ChainCommandExecutor {
    static func openApp(_ app: ChainSupportedApp, in directory: URL) {
        if app == .obsidian {
            openObsidian(in: directory)
            return
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
            ChainAlert.show("Cannot find \(app.applicationName)", detail: "Make sure it is installed.")
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.open([directory], withApplicationAt: appURL, configuration: config) { _, error in
            if let error {
                DispatchQueue.main.async {
                    ChainAlert.show("Failed to open \(app.applicationName)", detail: error.localizedDescription)
                }
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func openObsidian(in directory: URL) {
        if let url = obsidianVaultURL(for: directory) {
            NSWorkspace.shared.open(url)
            return
        }

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ChainSupportedApp.obsidian.bundleIdentifier) else {
            ChainAlert.show("Cannot find \(ChainSupportedApp.obsidian.applicationName)", detail: "Make sure it is installed.")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([], withApplicationAt: appURL, configuration: config, completionHandler: nil)
    }

    private static func obsidianVaultURL(for directory: URL) -> URL? {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/obsidian/obsidian.json")

        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let vaults = json["vaults"] as? [String: [String: Any]],
              let vault = vaults.values.first(where: { ($0["path"] as? String) == directory.path }),
              let vaultName = vault["name"] as? String
        else { return nil }

        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "vault", value: vaultName)]
        return components.url
    }

    static func createMarkdownFile(in directory: URL) {
        let dateString = dateFormatter.string(from: Date())

        let content = Data("---\ntitle: \ndate: \(dateString)\ntags:\n---\n".utf8)
        var fileURL = directory.appendingPathComponent("\(dateString).md")

        for counter in 1...1000 {
            do {
                try content.write(to: fileURL, options: .withoutOverwriting)
                return
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
                fileURL = directory.appendingPathComponent("\(dateString)_\(counter).md")
            } catch {
                ChainAlert.show("Failed to create file", detail: error.localizedDescription)
                return
            }
        }
        ChainAlert.show("Failed to create file", detail: "Too many notes created today.")
    }
}

enum ChainAlert {
    static func show(_ message: String, detail: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { show(message, detail: detail) }
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }
}
