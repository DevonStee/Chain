import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

@main
struct ChainMenuContextResolverTests {
    static func main() throws {
        let fileManager = FileManager.default
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let folderURL = root.appendingPathComponent("Folder", isDirectory: true)
        let fileURL = root.appendingPathComponent("note.txt", isDirectory: false)

        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        fileManager.createFile(atPath: fileURL.path, contents: Data(), attributes: nil)

        // Single-item resolution via targetDirectories
        expect(
            ChainMenuContextResolver.targetDirectories(for: .contextualContainer, targetedURL: folderURL, selectedItemURLs: nil) == [folderURL],
            "container click should resolve to the clicked folder"
        )

        expect(
            ChainMenuContextResolver.targetDirectories(for: .contextualItems, targetedURL: root, selectedItemURLs: [folderURL]) == [folderURL],
            "right-clicking a folder item should resolve to that folder"
        )

        expect(
            ChainMenuContextResolver.targetDirectories(for: .contextualItems, targetedURL: root, selectedItemURLs: [fileURL]) == [root],
            "right-clicking a file item should resolve to its parent directory"
        )

        expect(
            ChainMenuContextResolver.targetDirectories(for: .contextualItems, targetedURL: nil, selectedItemURLs: [folderURL]) == [folderURL],
            "selected folder should be usable when targetedURL is unavailable"
        )

        // --- targetDirectories (multi-selection) ---

        let folder2URL = root.appendingPathComponent("Folder2", isDirectory: true)
        try fileManager.createDirectory(at: folder2URL, withIntermediateDirectories: true)

        // Select 1 folder → 1 directory
        let single = ChainMenuContextResolver.targetDirectories(
            for: .contextualItems,
            targetedURL: root,
            selectedItemURLs: [folderURL]
        )
        expect(single == [folderURL], "single folder selection should return 1 directory")

        // Select 3 folders → 3 directories
        let multi = ChainMenuContextResolver.targetDirectories(
            for: .contextualItems,
            targetedURL: root,
            selectedItemURLs: [folderURL, folder2URL, root]
        )
        expect(multi.count == 3, "3 folder selection should return 3 directories")
        expect(multi[0] == folderURL, "first directory should be Folder")
        expect(multi[1] == folder2URL, "second directory should be Folder2")
        expect(multi[2] == root, "third directory should be root")

        // Select 2 files in same dir + 1 folder → dedup to 2 directories
        let file2URL = root.appendingPathComponent("readme.txt", isDirectory: false)
        fileManager.createFile(atPath: file2URL.path, contents: Data(), attributes: nil)

        let deduped = ChainMenuContextResolver.targetDirectories(
            for: .contextualItems,
            targetedURL: root,
            selectedItemURLs: [fileURL, file2URL, folderURL]
        )
        expect(deduped.count == 2, "2 files in same dir + 1 folder should dedup to 2 directories")
        expect(deduped[0] == root, "files should resolve to parent (root)")
        expect(deduped[1] == folderURL, "folder should stay as-is")

        // Folder background → 1 directory
        let background = ChainMenuContextResolver.targetDirectories(
            for: .contextualContainer,
            targetedURL: folderURL,
            selectedItemURLs: nil
        )
        expect(background == [folderURL], "folder background should return that folder")

        print("ChainMenuContextResolver tests passed")
    }
}
