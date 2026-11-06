import Foundation

@main
struct ChainMenuBarRequirementsTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Requirement failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let infoPlist = root.appendingPathComponent("Chain/Info.plist")

        let plistData = try Data(contentsOf: infoPlist)
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        let source = try ["Chain/ChainApp.swift", "Chain/MenuBarViews.swift"]
            .map { try String(contentsOf: root.appendingPathComponent($0), encoding: .utf8) }
            .joined(separator: "\n")

        require(plist?["LSUIElement"] as? Bool == true, "main app should run as a menu bar utility")
        require(source.contains("MenuBarExtra"), "app should use MenuBarExtra for the main UI")
        require(!source.contains("WindowGroup"), "app should not create a default main window scene")
        require(!source.contains("Window(\""), "app should not create a settings window scene")
        require(!source.contains("打开设置/说明"), "menu bar should not expose a settings action")

        print("Chain menu bar requirements passed")
    }
}
