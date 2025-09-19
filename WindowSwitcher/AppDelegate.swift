//
//  AppDelegate.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 19.09.25.
//

import AppKit


class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarHandler?
    private var appearanceObserver: NSKeyValueObservation?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.bool(forKey: "DockHidden") {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        updateAppIcon()

        // Observe changes to effectiveAppearance
        appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.new]) { _, _ in
            self.updateAppIcon()
        }

        // This will ask if not already granted
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true
        ]
        let granted = AXIsProcessTrustedWithOptions(options)
        print("Accessibility permission granted: \(granted)")
        
        _ = MenuBarHandler.shared
        _ = FloatingPanelHandler.shared
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        appearanceObserver?.invalidate()
    }


    func updateAppIcon() {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let iconName = isDark ? "AppIconDark" : "AppIconLight"
        if let icon = NSImage(named: iconName) {
            NSApp.applicationIconImage = icon
        }
    }
    
}
