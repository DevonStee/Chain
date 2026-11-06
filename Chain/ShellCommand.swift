import Foundation

struct ShellInvocation: Equatable {
    let executableURL: URL
    let arguments: [String]
}

/// Pure text building for commands run in a user's shell. No side effects, so it can be tested directly.
enum ShellCommand {
    static func quote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func fishQuote(_ s: String) -> String {
        "'" + s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'") + "'"
    }

    static func appleScriptEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    static func invocation(command: String, directory: URL, loginShell: URL) -> ShellInvocation {
        switch loginShell.lastPathComponent {
        case "fish":
            let wrapped = "cd \(fishQuote(directory.path)); and begin; \(command); end; set chain_status $status; printf '\\nPress return to close…'; read chain_close; exit $chain_status"
            return ShellInvocation(
                executableURL: loginShell,
                arguments: ["--login", "--interactive", "--command", wrapped]
            )
        case "zsh", "bash":
            return ShellInvocation(
                executableURL: loginShell,
                arguments: ["-lic", posixWrapper(command: command, directory: directory)]
            )
        default:
            return ShellInvocation(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", posixWrapper(command: command, directory: directory)]
            )
        }
    }

    private static func posixWrapper(command: String, directory: URL) -> String {
        "cd \(quote(directory.path)) && { \(command); }; status=$?; printf '\\nPress return to close…'; read -r chain_close; exit $status"
    }
}

/// How one terminal runs a custom command. To support a new terminal, add a case to
/// `make` and to `ChainSupportedApp.customCommandTerminals`; a test checks they match.
enum CustomCommandLaunch: Equatable {
    case appleScript(String)
    case cli(binaryName: String, arguments: [String])

    static func make(
        terminal: ChainSupportedApp,
        command: String,
        directory: URL,
        loginShell: URL
    ) -> CustomCommandLaunch? {
        let combined = ShellCommand.appleScriptEscape("cd \(ShellCommand.quote(directory.path)) && \(command)")
        let shell = ShellCommand.invocation(command: command, directory: directory, loginShell: loginShell)
        let shellArguments = [shell.executableURL.path] + shell.arguments

        switch terminal {
        case .terminal:
            return .appleScript(doScript(target: "application \"Terminal\"", command: combined))
        case .otty:
            // Otty's `do script` mirrors Terminal.app: with no target it opens a new window.
            return .appleScript(doScript(target: "application id \"\(terminal.bundleIdentifier)\"", command: combined))
        case .iterm2:
            // Always use a fresh window: writing into the current session would type the
            // command into whatever the user is running there (vim, a REPL, …).
            return .appleScript("""
            tell application id "\(terminal.bundleIdentifier)"
                activate
                set chainWindow to (create window with default profile)
                tell current session of chainWindow to write text "\(combined)"
            end tell
            """)
        case .kitty:
            return .cli(binaryName: "kitty", arguments: ["--directory=\(directory.path)"] + shellArguments)
        case .alacritty:
            return .cli(binaryName: "alacritty", arguments: ["--working-directory", directory.path, "-e"] + shellArguments)
        case .wezterm:
            return .cli(binaryName: "wezterm", arguments: ["start", "--cwd", directory.path, "--"] + shellArguments)
        default:
            return nil
        }
    }

    private static func doScript(target: String, command: String) -> String {
        """
        tell \(target)
            activate
            do script "\(command)"
        end tell
        """
    }
}
