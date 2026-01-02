//
//  AppDelegate.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 19.09.25.
//

import AppKit
import UserNotifications


class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
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
        UNUserNotificationCenter.current().delegate = self
        
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
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        
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
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
