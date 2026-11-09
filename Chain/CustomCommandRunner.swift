import AppKit
import Darwin

enum CustomCommandRunner {
    static func run(in directory: URL) {
        guard ChainSettings.customCommandIsActive else { return }
        let command = ChainSettings.customCommandText
        let terminal = ChainSettings.customCommandTerminal
        guard let launch = CustomCommandLaunch.make(
            terminal: terminal,
            command: command,
            directory: directory,
            loginShell: userLoginShellURL()
        ) else {
            ChainAlert.show("Unsupported terminal", detail: "\(terminal.applicationName) cannot run custom commands.")
            return
        }
        guard terminal.isInstalled else {
            ChainAlert.show("\(terminal.applicationName) is not installed", detail: "Install it or pick another terminal in Settings.")
            return
        }

        switch launch {
        case .appleScript(let source):
            runAppleScript(source, terminalName: terminal.applicationName)
        case .cli(let binaryName, let arguments):
            runCLI(terminal: terminal, binaryName: binaryName, arguments: arguments)
        }
    }

    private static func runCLI(terminal: ChainSupportedApp, binaryName: String, arguments: [String]) {
        guard let binary = cliBinaryURL(for: terminal, binaryName: binaryName) else {
            ChainAlert.show("Cannot find \(terminal.applicationName) CLI", detail: "Make sure \(terminal.applicationName) is installed correctly.")
            return
        }
        let process = Process()
        process.executableURL = binary
        process.arguments = arguments
        do {
            try process.run()
        } catch {
            ChainAlert.show("Failed to launch \(terminal.applicationName)", detail: error.localizedDescription)
        }
    }

    private static func cliBinaryURL(for app: ChainSupportedApp, binaryName: String) -> URL? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) else {
            return nil
        }
        let url = appURL.appendingPathComponent("Contents/MacOS").appendingPathComponent(binaryName)
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    private static func runAppleScript(_ source: String, terminalName: String) {
        guard let script = NSAppleScript(source: source) else {
            ChainAlert.show("Failed to run command", detail: "Could not build AppleScript for \(terminalName).")
            return
        }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            let message = (error[NSAppleScript.errorMessage] as? String) ?? "AppleScript error"
            ChainAlert.show("Failed to run command in \(terminalName)", detail: message)
        }
    }

    private static func userLoginShellURL() -> URL {
        let fallbackURL = URL(fileURLWithPath: "/bin/zsh")
        if let passwd = getpwuid(getuid()),
           let shellCString = passwd.pointee.pw_shell {
            let shellPath = String(cString: shellCString)
            let shellURL = URL(fileURLWithPath: shellPath)
            if FileManager.default.isExecutableFile(atPath: shellURL.path) {
                return shellURL
            }
        }

        if let shellPath = ProcessInfo.processInfo.environment["SHELL"], !shellPath.isEmpty {
            let shellURL = URL(fileURLWithPath: shellPath)
            if FileManager.default.isExecutableFile(atPath: shellURL.path) {
                return shellURL
            }
        }

        return fallbackURL
    }
}
