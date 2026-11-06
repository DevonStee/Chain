import Foundation

@main
struct ChainMenuPresentationTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() {
            fputs("Requirement failed: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let source = try String(
            contentsOf: root.appendingPathComponent("ChainExtension/FinderSync.swift"),
            encoding: .utf8
        )

        require(!source.contains(".image ="), "context menu should not set icons on menu items")
        require(!source.contains("mdItem.image"), "context menu should not set an icon for Markdown creation")

        print("Chain menu presentation requirements passed")
    }
}
