import Foundation

@main
struct ChainEnglishMenuRequirementsTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Requirement failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let extensionSource = try String(
            contentsOf: root.appendingPathComponent("ChainExtension/FinderSync.swift"),
            encoding: .utf8
        )
        let sharedSource = try String(
            contentsOf: root.appendingPathComponent("Chain/ChainAppSupport.swift"),
            encoding: .utf8
        )
        let appSource = try ["Chain/ChainApp.swift", "Chain/MenuBarViews.swift"]
            .map { try String(contentsOf: root.appendingPathComponent($0), encoding: .utf8) }
            .joined(separator: "\n")

        // Terminal menu titles
        require(sharedSource.contains("Open in \\(applicationName)"), "menu should derive app titles from shared English template")
        require(sharedSource.contains("return \"Terminal\""), "should expose English Terminal name")
        require(sharedSource.contains("return \"iTerm2\""), "should expose English iTerm2 name")
        require(sharedSource.contains("return \"kitty\""), "should expose English kitty name")
        require(sharedSource.contains("return \"Ghostty\""), "should expose English Ghostty name")
        require(sharedSource.contains("New Note"), "should expose English markdown action")

        // No Chinese text
        require(!extensionSource.contains("在 Terminal 中打开"), "should not ship Chinese terminal text")
        require(!sharedSource.contains("新建 Markdown 文件"), "should not ship Chinese markdown text")
        require(!appSource.contains("重启 Finder 扩展"), "should not ship Chinese restart text")
        require(!appSource.contains("退出"), "should not ship Chinese quit text")

        // Menu bar strings
        require(sharedSource.contains("Launch at Login"), "should expose English launch at login")
        require(sharedSource.contains("Not Showing?"), "should expose English reload action")
        require(sharedSource.contains("quitTitle = \"Quit\""), "should expose English quit action")
        let oldQuitTitle = "Quit " + "Chain"
        require(!sharedSource.contains(oldQuitTitle), "quit action should not repeat app name")

        // Menu bar uses MenuBarExtra with custom image
        require(appSource.contains("MenuBarExtra"), "app should use MenuBarExtra")
        require(appSource.contains("MenuBarIcon"), "menu bar should use custom icon asset")

        print("Chain English menu requirements passed")
    }
}
