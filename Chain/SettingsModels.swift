import ServiceManagement
import SwiftUI

@MainActor
final class LaunchAtLoginModel: ObservableObject {
    @Published private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    @Published var errorMessage: String?

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isEnabled = enabled
        } catch {
            errorMessage = error.localizedDescription
            isEnabled = SMAppService.mainApp.status == .enabled
        }
    }
}

@MainActor
final class AppSelectionModel: ObservableObject {
    @Published var selectedApps: Set<ChainSupportedApp>
    @Published var installedApps: [ChainSupportedApp] = []

    init() {
        selectedApps = Set(ChainSettings.selectedApps)
        refreshInstalled()
    }

    func refreshInstalled() {
        installedApps = ChainSupportedApp.allCases.filter(\.isInstalled)
        var pruned = selectedApps.filter { installedApps.contains($0) }
        if pruned.isEmpty, let first = installedApps.first {
            pruned = [first]
        }
        if pruned != selectedApps {
            selectedApps = pruned
            save()
        }
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
        // Preserve enum ordering
        let ordered = ChainSupportedApp.allCases.filter { selectedApps.contains($0) }
        ChainSettings.setSelectedApps(ordered)
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

    var canEnable: Bool { !command.isEmpty && !installedTerminals.isEmpty }
}
