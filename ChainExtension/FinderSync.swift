import Cocoa
import FinderSync

class FinderSync: FIFinderSync {
    private static let markdownTag = -1
    private var lastMenuKind: ChainMenuKind = .contextualItems
    private var lastSelectedApps: [ChainSupportedApp] = []

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

        lastSelectedApps = ChainSettings.selectedApps.filter(\.isInstalled)

        let menu = NSMenu(title: "")

        for (index, app) in lastSelectedApps.enumerated() {
            let item = NSMenuItem(title: app.menuTitle, action: #selector(openIn(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.setAccessibilityLabel("Open this folder in \(app.applicationName)")
            menu.addItem(item)
        }

        let mdItem = NSMenuItem(title: ChainAppCatalog.newMarkdownTitle, action: #selector(createMarkdownFile(_:)), keyEquivalent: "")
        mdItem.target = self
        mdItem.tag = Self.markdownTag
        mdItem.setAccessibilityLabel("Create a new note in this folder")
        menu.addItem(mdItem)

        if ChainSettings.customCommandEnabled && !ChainSettings.customCommandText.isEmpty {
            let ccItem = NSMenuItem(title: ChainSettings.effectiveCustomCommandLabel, action: #selector(runCustomCommand(_:)), keyEquivalent: "")
            ccItem.target = self
            ccItem.setAccessibilityLabel("Run the configured custom command in this folder")
            menu.addItem(ccItem)
        }

        return menu
    }

    @objc func openIn(_ sender: NSMenuItem) {
        guard sender.tag >= 0, sender.tag < lastSelectedApps.count else { return }
        let app = lastSelectedApps[sender.tag]
        for directory in currentTargetDirectories() {
            sendCommand(.openIn, directory: directory, app: app)
        }
    }

    @objc func createMarkdownFile(_ sender: NSMenuItem) {
        for directory in currentTargetDirectories() {
            sendCommand(.createMarkdownFile, directory: directory)
        }
    }

    @objc func runCustomCommand(_ sender: NSMenuItem) {
        for directory in currentTargetDirectories() {
            sendCommand(.runCustomCommand, directory: directory)
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

    private func sendCommand(_ action: ChainCommandAction, directory: URL, app: ChainSupportedApp? = nil) {
        guard let url = ChainCommandURL.makeURL(action: action, directory: directory, app: app) else { return }
        if !NSWorkspace.shared.open(url) {
            NSLog("Chain: failed to open command URL for \(action.rawValue)")
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
