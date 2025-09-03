//
//  WindowSwitcherApp.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import SwiftUI

@main
struct WindowSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
        _ = FloatingPanelHandler.shared
    }
}
