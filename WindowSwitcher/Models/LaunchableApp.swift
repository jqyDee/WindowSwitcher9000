//
//  LaunchableApp.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//

import Foundation
import AppKit


public struct LaunchableApp: Identifiable {
    public let id = UUID()
    let name: String
    let bundleID: String?
    let icon: NSImage?
}

