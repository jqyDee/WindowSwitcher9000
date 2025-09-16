//
//  AppLauncher.swift
//  WindowSwitcher
//
//  Created by Copilot on 2025-09-15.
//

import Foundation
import AppKit

public struct AppLauncher {
    /// Attempts to launch an app by its display name (using `/usr/bin/open -a`).
    /// - Parameter appName: The display name of the application, e.g. "Finder" or "Safari".
    public static func openAppByName(_ appName: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appName]
        do {
            try process.run()
        } catch {
            print("Failed to open app \(appName): \(error)")
        }
    }

    /// Attempts to launch an app via its bundle identifier.
    /// - Parameter bundleIdentifier: The bundle ID, e.g. "com.apple.Safari".
    /// - Returns: true if the app was successfully opened, false otherwise.
    @discardableResult
    public static func openAppByBundleIdentifier(_ bundleIdentifier: String) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return false
        }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, err in
            if let err {
                print("open app error:", err)
            }
        }
        return true
    }
}
