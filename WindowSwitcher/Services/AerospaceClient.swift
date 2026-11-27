//
//  AerospaceClient.swift
//  WindowSwitcher
//

import Foundation

public enum AerospaceError: Error {
    case failed(Int32, Data)
    case decoding(Error)
}

/// Queries and focuses windows through the AeroSpace CLI (https://github.com/nikitabobko/AeroSpace).
public actor AerospaceClient: WindowServiceProtocol {
    public let aerospacePath: URL

    public init(aerospacePath: String? = nil) {
        self.aerospacePath = aerospacePath.map { URL(fileURLWithPath: $0) } ?? ExecutableResolver.resolve("aerospace")
    }

    private struct AerospaceWindow: Decodable {
        let windowId: Int
        let appName: String
        let windowTitle: String
        let appPid: Int32
        let appBundleId: String?
        let workspace: String?

        enum CodingKeys: String, CodingKey {
            case windowId = "window-id"
            case appName = "app-name"
            case windowTitle = "window-title"
            case appPid = "app-pid"
            case appBundleId = "app-bundle-id"
            case workspace
        }
    }

    private func run(arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = aerospacePath
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        // Read before waiting so large outputs can't fill the pipe and block the process
        let out = outPipe.fileHandleForReading.readDataToEndOfFile()
        let err = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw AerospaceError.failed(process.terminationStatus, err)
        }
        return out
    }

    public func queryWindows() async throws -> [Window] {
        let data = try run(arguments: [
            "list-windows", "--all", "--json",
            "--format", "%{window-id}%{app-name}%{window-title}%{app-pid}%{app-bundle-id}%{workspace}",
        ])
        let windows: [AerospaceWindow]
        do {
            windows = try JSONDecoder().decode([AerospaceWindow].self, from: data)
        } catch {
            throw AerospaceError.decoding(error)
        }
        return windows.map { w in
            Window(
                id: String(w.windowId),
                app: w.appName,
                // AeroSpace only lists real managed windows, but some (e.g. System Settings) have no title.
                // Fall back to the app name so the view model's empty-title filter keeps them.
                title: w.windowTitle.isEmpty ? w.appName : w.windowTitle,
                // Workspaces can have arbitrary names; non-numeric ones map to -1.
                space: w.workspace.flatMap { Int($0) } ?? -1,
                pid: w.appPid,
                bundleID: w.appBundleId
            )
        }
    }

    // `focus --window-id` also switches to the window's workspace, so `space` is not needed.
    public func focus(space: Int, windowId: String) async throws {
        _ = try run(arguments: ["focus", "--window-id", windowId])
    }

    /// Fire-and-forget version of focus that does not block
    nonisolated public func focusFast(space: Int, windowId: String) {
        let path = aerospacePath
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = path
            task.arguments = ["focus", "--window-id", windowId]
            try? task.run()
        }
    }
}
