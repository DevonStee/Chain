import Foundation

enum ChainMaintenance {
    private static let extensionBundleIdentifier = "com.lursetawet.chain.ChainExtension"

    static func restartFinderExtension() {
        Task.detached(priority: .userInitiated) {
            _ = await registerFinderExtension()
        }
    }

    /// Returns whether pluginkit accepted the extension.
    static func registerFinderExtension() async -> Bool {
        do {
            if let extensionURL = finderExtensionURL() {
                try await run("/usr/bin/pluginkit", arguments: ["-a", extensionURL.path])
            }
            try await run("/usr/bin/pluginkit", arguments: ["-e", "use", "-i", extensionBundleIdentifier])
            return true
        } catch {
            NSLog("Chain: failed to register extension - \(error)")
            return false
        }
    }

    private static func finderExtensionURL() -> URL? {
        Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("ChainExtension.appex", isDirectory: true)
    }

    private static func run(_ path: String, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            do {
                process.terminationHandler = { proc in
                    if proc.terminationStatus == 0 {
                        cont.resume()
                    } else {
                        cont.resume(throwing: NSError(
                            domain: "ChainMaintenance",
                            code: Int(proc.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: "\(path) exited with status \(proc.terminationStatus)"]
                        ))
                    }
                }
                try process.run()
            } catch {
                process.terminationHandler = nil
                cont.resume(throwing: error)
            }
        }
    }
}
