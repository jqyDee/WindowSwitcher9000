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
    var menuBarController: MenuBarHandler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarHandler()
        _ = FloatingPanelHandler.shared
    }
}
