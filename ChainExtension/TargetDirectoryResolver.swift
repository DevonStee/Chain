import Foundation

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

enum ChainMenuKind {
    case contextualContainer
    case contextualItems
}

enum ChainMenuContextResolver {
    static func targetDirectories(
        for menuKind: ChainMenuKind,
        targetedURL: URL?,
        selectedItemURLs: [URL]?
    ) -> [URL] {
        switch menuKind {
        case .contextualItems:
            if let urls = selectedItemURLs, !urls.isEmpty {
                return urls.map { normalizeDirectoryCandidate($0) }.uniqued()
            }
            if let targetedURL {
                return [normalizeDirectoryCandidate(targetedURL)]
            }
        case .contextualContainer:
            if let targetedURL {
                return [normalizeDirectoryCandidate(targetedURL)]
            }
        }
        return []
    }

    private static func normalizeDirectoryCandidate(_ url: URL) -> URL {
        if url.hasDirectoryPath { return url }

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return url
        }

        return url.deletingLastPathComponent()
    }
}
