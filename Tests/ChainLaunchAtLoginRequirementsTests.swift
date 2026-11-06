import Foundation

@main
struct ChainLaunchAtLoginRequirementsTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Requirement failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let appSource = try String(
            contentsOf: root.appendingPathComponent("Chain/SettingsModels.swift"),
            encoding: .utf8
        )
        let sharedSource = try String(
            contentsOf: root.appendingPathComponent("Chain/ChainAppSupport.swift"),
            encoding: .utf8
        )
        let projectSource = try String(
            contentsOf: root.appendingPathComponent("Chain.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )

        require(sharedSource.contains("Launch at Login"), "menu bar should expose a Launch at Login toggle")
        require(appSource.contains("SMAppService.mainApp"), "launch at login should use the native main app service")
        require(projectSource.contains("ChainExtension.appex in Embed Foundation Extensions"), "main app should still embed the Finder extension")
        require(!projectSource.contains("Embed Helper Apps"), "main app should not embed the old helper login item")
        require(!projectSource.contains("Contents/Library/LoginItems"), "main app should not ship a login item helper payload")

        print("Chain launch at login requirements passed")
    }
}
