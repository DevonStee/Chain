import Cocoa
import FinderSync

class FinderSync: FIFinderSync {
    private static let markdownTag = -1
    private var lastMenuKind: ChainMenuKind = .contextualItems

    override init() {
        super.init()
        updateWatchedDirectories()

        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(updateWatchedDirectories),
                       name: NSWorkspace.didMountNotification, object: nil)
        nc.addObserver(self, selector: #selector(updateWatchedDirectories),
                       name: NSWorkspace.didUnmountNotification, object: nil)
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func updateWatchedDirectories() {
        var urls: Set<URL> = [URL(fileURLWithPath: "/")]
        let volumeKeys: [URLResourceKey] = [.volumeIsRootFileSystemKey]
        if let volumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: volumeKeys,
                                                               options: [.skipHiddenVolumes]) {
            urls.formUnion(volumes)
        }
        FIFinderSyncController.default().directoryURLs = urls
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let controller = FIFinderSyncController.default()
        guard let kind = menuKind.chainMenuKind else {
            return NSMenu(title: "")
        }
        lastMenuKind = kind
        let targetDirectories = ChainMenuContextResolver.targetDirectories(
            for: kind,
            targetedURL: controller.targetedURL(),
            selectedItemURLs: controller.selectedItemURLs()
        )
        guard !targetDirectories.isEmpty else {
            return NSMenu(title: "")
        }

        guard ChainSettings.commandNonce != nil else {
            return finishSetupMenu()
        }

        let menu = NSMenu(title: "")

        // The stored list can exceed the limit while a remembered app has just come back.
        let apps = ChainSettings.selectedApps.filter(\.isInstalled).prefix(ChainSettings.maxSelection)
        for app in apps {
            guard let appIndex = ChainSupportedApp.allCases.firstIndex(of: app) else { continue }
            let item = NSMenuItem(title: app.menuTitle, action: #selector(openIn(_:)), keyEquivalent: "")
            item.target = self
            // The tag identifies the app by itself, so the click needs nothing saved from this build.
            item.tag = appIndex
            item.setAccessibilityLabel("Open this folder in \(app.applicationName)")
            menu.addItem(item)
        }

        let mdItem = NSMenuItem(title: ChainAppCatalog.newMarkdownTitle, action: #selector(createMarkdownFile(_:)), keyEquivalent: "")
        mdItem.target = self
        mdItem.tag = Self.markdownTag
        mdItem.setAccessibilityLabel("Create a new note in this folder")
        menu.addItem(mdItem)

        if ChainSettings.customCommandIsActive {
            let ccItem = NSMenuItem(title: ChainSettings.effectiveCustomCommandLabel, action: #selector(runCustomCommand(_:)), keyEquivalent: "")
            ccItem.target = self
            ccItem.setAccessibilityLabel("Run the configured custom command in this folder")
            menu.addItem(ccItem)
        }

        return menu
    }

    /// Shown until the main app has created the nonce; commands would be rejected before that.
    private func finishSetupMenu() -> NSMenu {
        let menu = NSMenu(title: "")
        let item = NSMenuItem(title: ChainAppCatalog.finishSetupTitle, action: #selector(finishSetup(_:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc func finishSetup(_ sender: NSMenuItem) {
        guard let url = ChainCommandURL.finishSetupURL, NSWorkspace.shared.open(url) else {
            NSLog("Chain: failed to launch the main app")
            return
        }
    }

    @objc func openIn(_ sender: NSMenuItem) {
        guard ChainSupportedApp.allCases.indices.contains(sender.tag) else { return }
        let app = ChainSupportedApp.allCases[sender.tag]
        for directory in currentTargetDirectories() {
            sendCommand(.openIn(app, directory: directory))
        }
    }

    @objc func createMarkdownFile(_ sender: NSMenuItem) {
        for directory in currentTargetDirectories() {
            sendCommand(.createMarkdownFile(directory: directory))
        }
    }

    @objc func runCustomCommand(_ sender: NSMenuItem) {
        for directory in currentTargetDirectories() {
            sendCommand(.runCustomCommand(directory: directory))
        }
    }

    private func currentTargetDirectories() -> [URL] {
        let controller = FIFinderSyncController.default()
        return ChainMenuContextResolver.targetDirectories(
            for: lastMenuKind,
            targetedURL: controller.targetedURL(),
            selectedItemURLs: controller.selectedItemURLs()
        )
    }

    private func sendCommand(_ command: ChainCommand) {
        guard let url = ChainCommandURL.makeURL(command) else {
            NSLog("Chain: command URL could not be built")
            return
        }
        if !NSWorkspace.shared.open(url) {
            NSLog("Chain: failed to open command URL for %@", url.host ?? "unknown")
        }
    }
}

private extension FIMenuKind {
    var chainMenuKind: ChainMenuKind? {
        switch self {
        case .contextualMenuForContainer: .contextualContainer
        case .contextualMenuForItems: .contextualItems
        default: nil
        }
    }
}
