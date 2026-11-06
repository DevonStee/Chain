import AppKit
import SwiftUI

struct CustomCommandSettingsView: View {
    @ObservedObject private var model = CustomCommandModel.shared
    @FocusState private var commandFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Picker("Terminal", selection: $model.terminal) {
                    ForEach(model.installedTerminals, id: \.self) { app in
                        Text(app.applicationName).tag(app)
                    }
                }
                .disabled(model.installedTerminals.isEmpty)

                TextField("Label Name", text: $model.label, prompt: Text(ChainAppCatalog.customCommandTitle))
                TextField("Command", text: $model.command, prompt: Text("Command to run"))
                    .focused($commandFocused)
                LabeledContent(" ") {
                    Text(ChainAppCatalog.customCommandSettingsHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Spacer()
                Button("Done") {
                    CustomCommandPanelController.shared.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear {
            model.refreshInstalled()
            DispatchQueue.main.async {
                commandFocused = true
            }
        }
    }
}

final class CustomCommandPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

@MainActor
final class CustomCommandPanelController: NSObject, NSWindowDelegate {
    static let shared = CustomCommandPanelController()

    private var panel: NSPanel?

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        panel?.close()
        panel = nil
    }

    private static let frameAutosaveName = "com.lursetawet.chain.CustomCommandPanel"

    private func makePanel() -> NSPanel {
        let controller = NSHostingController(rootView: CustomCommandSettingsView())
        let panel = CustomCommandPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 210),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Custom Command Options"
        panel.contentViewController = controller
        panel.isReleasedWhenClosed = false
        panel.isRestorable = false
        panel.identifier = NSUserInterfaceItemIdentifier("custom-command")
        panel.delegate = self

        let autosaveKey = "NSWindow Frame \(Self.frameAutosaveName)"
        let hasSavedFrame = UserDefaults.standard.string(forKey: autosaveKey) != nil
        panel.setFrameAutosaveName(Self.frameAutosaveName)
        if !hasSavedFrame {
            panel.center()
        }
        return panel
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSPanel === panel {
            panel = nil
        }
    }
}

struct MenuBarContentView: View {
    @StateObject private var launchAtLoginModel = LaunchAtLoginModel()
    @StateObject private var appSelectionModel = AppSelectionModel()
    @ObservedObject private var customCommandModel = CustomCommandModel.shared

    var body: some View {
        Section {
            ForEach(appSelectionModel.installedApps, id: \.self) { app in
            Toggle(
                app.applicationName,
                isOn: Binding(
                    get: { appSelectionModel.isSelected(app) },
                    set: { _ in appSelectionModel.toggle(app) }
                )
            )
            .disabled(appSelectionModel.isDisabled(app))
            }

            Toggle(
                ChainAppCatalog.customCommandTitle,
                isOn: $customCommandModel.enabled
            )
            .disabled(!customCommandModel.canEnable)
        } header: {
            Text("Open In (\(appSelectionModel.selectedApps.count)/\(ChainSettings.maxSelection))")
        }
        .onAppear {
            appSelectionModel.refreshInstalled()
            customCommandModel.refreshInstalled()
        }

        Divider()

        Button {
            CustomCommandPanelController.shared.show()
        } label: {
            Label("Command Options…", systemImage: "slider.horizontal.3")
        }

        Divider()

        Toggle(
            isOn: Binding(
                get: { launchAtLoginModel.isEnabled },
                set: { launchAtLoginModel.setEnabled($0) }
            )
        ) {
            Label(ChainAppCatalog.launchAtLoginTitle, systemImage: "arrow.up.forward.app")
        }

        if let errorMessage = launchAtLoginModel.errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
        }

        Button {
            ChainMaintenance.restartFinderExtension()
        } label: {
            Label(ChainAppCatalog.restartFinderExtensionTitle, systemImage: "arrow.clockwise")
        }

        Divider()

        Button {
            NSApp.terminate(nil)
        } label: {
            Label(ChainAppCatalog.quitTitle, systemImage: "power")
        }
    }
}
