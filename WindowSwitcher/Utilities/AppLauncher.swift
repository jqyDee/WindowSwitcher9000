//
//  AppLauncher.swift
//  WindowSwitcher
//
//  Created by Copilot on 2025-09-15.
//

import Foundation
import AppKit

public struct AppLauncher {
    public static func openAppByName(_ appName: String) {
        executeOpen(arguments: ["-a", appName])
    }

    public static func openByBundleID(_ bundleID: String) {
        executeOpen(arguments: ["-b", bundleID])
    }

    private static func executeOpen(arguments: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = arguments
            
            let errorPipe = Pipe()
            process.standardError = errorPipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus != 0 {
                    let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                                     ?? "Application not found."

                    NotificationService.shared.dispatch(
                        title: "Launch Failed",
                        message: errorString
                    )
                }
            } catch {
                NotificationService.shared.dispatch(
                    title: "System Error",
                    message: "Failed to execute launch command: \(error.localizedDescription)"
                )
            }
        }
    }
}
