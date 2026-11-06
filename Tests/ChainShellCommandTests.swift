import Foundation

@main
struct ChainShellCommandTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Requirement failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static let directory = URL(fileURLWithPath: "/tmp/project", isDirectory: true)

    static func main() throws {
        testShellSelection()
        testQuoting()
        try testPosixWrapperRunsSafelyInHostileDirectory()
        testEveryCustomCommandTerminalHasALaunch()
        testAppleScriptLaunches()
        testCLILaunches()
        print("Chain shell command tests passed")
    }

    static func testShellSelection() {
        for name in ["zsh", "bash"] {
            let shell = URL(fileURLWithPath: "/bin/\(name)")
            let result = ShellCommand.invocation(command: "ls", directory: directory, loginShell: shell)
            require(result.executableURL == shell, "\(name) should keep using the login shell")
            require(result.arguments.first == "-lic", "\(name) should run a login interactive command")
        }

        let fish = URL(fileURLWithPath: "/opt/homebrew/bin/fish")
        let fishResult = ShellCommand.invocation(command: "ls", directory: directory, loginShell: fish)
        require(fishResult.executableURL == fish, "fish should keep using the login shell")
        require(fishResult.arguments.prefix(3) == ["--login", "--interactive", "--command"], "fish should use its own flags")
        require(fishResult.arguments.last?.contains("; and begin; ls; end;") == true, "fish should use its own syntax")

        let nu = URL(fileURLWithPath: "/opt/homebrew/bin/nu")
        let fallback = ShellCommand.invocation(command: "ls", directory: directory, loginShell: nu)
        require(fallback.executableURL.path == "/bin/sh", "unknown shells should fall back to /bin/sh")
        require(fallback.arguments.first == "-c", "fallback /bin/sh should use POSIX -c, not -lc")
    }

    static func testQuoting() {
        require(ShellCommand.quote("it's") == "'it'\\''s'", "POSIX quote should escape single quotes")
        require(ShellCommand.fishQuote("it's \\x") == "'it\\'s \\\\x'", "fish quote should escape quotes and backslashes")
        require(ShellCommand.appleScriptEscape("say \"a\\b\"") == "say \\\"a\\\\b\\\"", "AppleScript escape should cover quotes and backslashes")
    }

    /// Runs the real wrapper: a folder name must never be interpreted as shell code.
    static func testPosixWrapperRunsSafelyInHostileDirectory() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("chain-test-\(UUID().uuidString)", isDirectory: true)
        let hostile = base.appendingPathComponent("it's a \"dir\" $(touch injected)", isDirectory: true)
        try FileManager.default.createDirectory(at: hostile, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let invocation = ShellCommand.invocation(
            command: "pwd > result.txt; false",
            directory: hostile,
            loginShell: URL(fileURLWithPath: "/bin/unknown-shell")
        )
        let process = Process()
        process.executableURL = invocation.executableURL
        process.arguments = invocation.arguments
        process.currentDirectoryURL = base
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        let result = try String(contentsOf: hostile.appendingPathComponent("result.txt"), encoding: .utf8)
        require(result.contains(hostile.lastPathComponent), "command should run inside the selected directory")
        require(process.terminationStatus == 1, "the wrapper should keep the command's exit status")
        for folder in [base, hostile] {
            let injected = folder.appendingPathComponent("injected").path
            require(!FileManager.default.fileExists(atPath: injected), "a folder name must not run as a command")
        }
    }

    static func launch(_ terminal: ChainSupportedApp, command: String = "ls") -> CustomCommandLaunch? {
        CustomCommandLaunch.make(
            terminal: terminal,
            command: command,
            directory: directory,
            loginShell: URL(fileURLWithPath: "/bin/zsh")
        )
    }

    static func testEveryCustomCommandTerminalHasALaunch() {
        let launchable = Set(ChainSupportedApp.allCases.filter { launch($0) != nil })
        require(launchable == Set(ChainSupportedApp.customCommandTerminals),
                "customCommandTerminals and CustomCommandLaunch.make must list the same terminals")
    }

    static func testAppleScriptLaunches() {
        guard case .appleScript(let iterm)? = launch(.iterm2) else {
            return require(false, "iTerm2 should use AppleScript")
        }
        require(iterm.contains("set chainWindow to (create window with default profile)"), "iTerm2 should run commands in a new window")
        require(!iterm.contains("current session of current window"), "iTerm2 must not type into the user's active session")

        guard case .appleScript(let terminal)? = launch(.terminal, command: "say \"hi\"") else {
            return require(false, "Terminal should use AppleScript")
        }
        require(terminal.contains("tell application \"Terminal\""), "should target Terminal")
        require(terminal.contains("do script \"cd '/tmp/project' && say \\\"hi\\\"\""), "should escape the command for AppleScript")

        guard case .appleScript(let otty)? = launch(.otty) else {
            return require(false, "Otty should use AppleScript")
        }
        require(otty.contains("tell application id \"io.appmakes.otty\""), "should target Otty by bundle ID")
    }

    static func testCLILaunches() {
        let cases: [(ChainSupportedApp, String, [String])] = [
            (.kitty, "kitty", ["--directory=/tmp/project", "/bin/zsh", "-lic"]),
            (.alacritty, "alacritty", ["--working-directory", "/tmp/project", "-e", "/bin/zsh", "-lic"]),
            (.wezterm, "wezterm", ["start", "--cwd", "/tmp/project", "--", "/bin/zsh", "-lic"]),
        ]
        for (terminal, binary, prefix) in cases {
            guard case .cli(let binaryName, let arguments)? = launch(terminal) else {
                return require(false, "\(terminal) should use its CLI")
            }
            require(binaryName == binary, "\(terminal) should use the \(binary) binary")
            require(Array(arguments.prefix(prefix.count)) == prefix, "\(terminal) arguments should start with \(prefix)")
        }
    }
}
