import ServiceManagement
import SwiftUI

@MainActor
final class LaunchAtLoginModel: ObservableObject {
    @Published private(set) var status = SMAppService.mainApp.status
    @Published var errorMessage: String?

    var isEnabled: Bool { status == .enabled }
    var requiresApproval: Bool { status == .requiresApproval }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
final class AppSelectionModel: ObservableObject {
    @Published var selectedApps: Set<ChainSupportedApp>
    @Published var installedApps: [ChainSupportedApp] = []
    private var unavailableApps: Set<ChainSupportedApp> = []

    init() {
        selectedApps = Set(ChainSettings.selectedApps)
        refreshInstalled()
    }

    func refreshInstalled() {
        installedApps = ChainSupportedApp.allCases.filter(\.isInstalled)
        let current = ChainAppSelection(active: selectedApps, unavailable: unavailableApps)
        let next = current.reconciled(installed: installedApps, maxCount: ChainSettings.maxSelection)
        guard next != current else { return }
        selectedApps = next.active
        unavailableApps = next.unavailable
        save()
    }

    func toggle(_ app: ChainSupportedApp) {
        if selectedApps.contains(app) {
            guard selectedApps.count > 1 else { return }
            selectedApps.remove(app)
        } else {
            guard selectedApps.count < ChainSettings.maxSelection else { return }
            selectedApps.insert(app)
        }
        save()
    }

    func isSelected(_ app: ChainSupportedApp) -> Bool {
        selectedApps.contains(app)
    }

    func isDisabled(_ app: ChainSupportedApp) -> Bool {
        if selectedApps.contains(app) {
            return selectedApps.count <= 1
        }
        return selectedApps.count >= ChainSettings.maxSelection
    }

    private func save() {
        ChainSettings.setSelectedApps(ChainAppSelection(active: selectedApps, unavailable: unavailableApps).persisted)
    }
}

@MainActor
final class CustomCommandModel: ObservableObject {
    static let shared = CustomCommandModel()

    @Published var command: String {
        didSet {
            guard command != oldValue else { return }
            ChainSettings.setCustomCommandText(command)
        }
    }
    @Published var terminal: ChainSupportedApp {
        didSet {
            guard terminal != oldValue else { return }
            ChainSettings.setCustomCommandTerminal(terminal)
        }
    }
    @Published var enabled: Bool {
        didSet {
            guard enabled != oldValue else { return }
            ChainSettings.setCustomCommandEnabled(enabled)
        }
    }
    @Published var label: String {
        didSet {
            guard label != oldValue else { return }
            ChainSettings.setCustomCommandLabel(label)
        }
    }
    @Published var installedTerminals: [ChainSupportedApp] = []

    private init() {
        command = ChainSettings.customCommandText
        terminal = ChainSettings.customCommandTerminal
        enabled = ChainSettings.customCommandEnabled
        label = ChainSettings.customCommandLabel
        refreshInstalled()
    }

    func refreshInstalled() {
        let installed = ChainSupportedApp.customCommandTerminals.filter(\.isInstalled)
        installedTerminals = installed
        if !installed.contains(terminal), let first = installed.first {
            terminal = first
        }
    }

    var canEnable: Bool { ChainSettings.isRunnableCommand(command) && !installedTerminals.isEmpty }
    var isActive: Bool { enabled && canEnable }
}
