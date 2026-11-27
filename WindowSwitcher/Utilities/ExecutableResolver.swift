//
//  ExecutableResolver.swift
//  WindowSwitcher
//

import Foundation

enum ExecutableResolver {
    /// Resolves a CLI tool's path via `which`, falling back to the Homebrew (Apple Silicon) location.
    static func resolve(_ name: String) -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        // GUI apps get a stripped PATH from launchd; inject Homebrew paths so `which` can find the tool
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        if (try? process.run()) != nil {
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if process.terminationStatus == 0,
               let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
        }
        return URL(fileURLWithPath: "/opt/homebrew/bin/\(name)")
    }
}
