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

    func applicationWillFinishLaunching(_ notification: Notification) {
        // The dock icon is hidden unless the user turned it on; without this, a fresh install read `false`.
        UserDefaults.standard.register(defaults: ["DockHidden": true])
        if UserDefaults.standard.bool(forKey: "DockHidden") {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        

        // The setup window asks for permissions (first launch, or whenever Accessibility is missing)
        if OnboardingHandler.shared.shouldShowOnLaunch {
            OnboardingHandler.shared.showOnLaunch()
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        
        _ = MenuBarHandler.shared
        _ = FloatingPanelHandler.shared
        ClipboardViewModel.shared.startMonitoring()
    }
    


    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
