//
//  AppLauncher.swift
//  WindowSwitcher
//
//  Created by Copilot on 2025-09-15.
//

import Foundation
import AppKit

import AppKit

public struct AppLauncher {
    public static func openAppByName(_ appName: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-a", appName]
            _ = try? process.run()   // fire & forget, ignore errors
        }
    }
}
