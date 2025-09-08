//
//  WindowSwitcherApp.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import SwiftUI
import ApplicationServices

@main
struct WindowSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var menuBarController: MenuBarHandler?
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.bool(forKey: "DockHidden") {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // This will ask if not already granted
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true
        ]
        let granted = AXIsProcessTrustedWithOptions(options)
        print("Accessibility permission granted: \(granted)")
        
        _ = MenuBarHandler.shared
        _ = FloatingPanelHandler.shared
    }
}
