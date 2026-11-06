import Foundation

// Keep a named native parent process so macOS can identify the background item.
guard CommandLine.arguments.count == 2 else {
    fputs("Usage: Chain Auto Build <repair-script>\n", stderr)
    exit(1)
}

let repair = Process()
repair.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
repair.arguments = [CommandLine.arguments[1]]
do {
    try repair.run()
    repair.waitUntilExit()
    exit(repair.terminationStatus)
} catch {
    fputs("Chain Auto Build failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
