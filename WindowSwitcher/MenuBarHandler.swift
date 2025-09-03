//
//  MenuBarHandler.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import SwiftUI
import AppKit

// MARK: - Menu Bar Handler

class MenuBarHandler {
    static let shared = MenuBarHandler()
    
    private var statusItem: NSStatusItem
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenuBar()
        showBarIcon()
    }
}

// MARK: - Public API

extension MenuBarHandler {
    @objc func showBarIcon() {
        statusItem.isVisible = true
    }
    
    @objc func hideBarIcon() {
        statusItem.isVisible = false
    }
    
    @objc func toggleDockIcon() {
        if UserDefaults.standard.bool(forKey: "DockHidden") {
            // HIDE
            NSApp.setActivationPolicy(.regular)
            UserDefaults.standard.set(false, forKey: "DockHidden")
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // SHOW
            NSApp.setActivationPolicy(.accessory)
            UserDefaults.standard.set(true, forKey: "DockHidden")
        }
    }
    
    @objc func openSettings() {
        print("MenuBarHandler : Open settings")
        
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.center()
        settingsWindow.title = "Settings"
        settingsWindow.contentView = NSHostingView(rootView: SettingsView())
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        print("MenuBarHandler : Quitting")
        NSApp.terminate(nil)
    }
    
    @objc func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        return AXIsProcessTrustedWithOptions(options)
    }
}

// MARK: - Setup

private extension MenuBarHandler {
    func setupMenuBar() {
        configureStatusButton()
        statusItem.menu = buildMenu()
    }
    
    func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "rectangle.3.offgrid",
            accessibilityDescription: "Window Switcher"
        )
        button.action = #selector(statusItemClicked)
        button.target = self
    }
    
    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        
        menu.addItem(makeMenuItem(
            title: "Toggle Switcher",
            action: #selector(toggleSwitcher),
            key: ""
        ))
        
        menu.addItem(makeMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            key: ","
        ))
        
        menu.addItem(.separator())
        
        menu.addItem(makeMenuItem(
            title: "Hide Menu Bar Icon",
            action: #selector(hideBarIcon)
        ))
        
        menu.addItem(makeMenuItem(
            title: "Toggle Dock Icon",
            action: #selector(toggleDockIcon)
        ))
        
        menu.addItem(makeMenuItem(
            title: "Check Permissions",
            action: #selector(checkAccessibilityPermission)
        ))

        menu.addItem(.separator())
        
        menu.addItem(makeMenuItem(
            title: "Quit",
            action: #selector(quit),
            key: "q"
        ))
        
        return menu
    }
    
    func makeMenuItem(title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }
}

// MARK: - Actions

@objc extension MenuBarHandler {
    @objc func statusItemClicked() {
        print("MenuBarHandler : Status bar icon clicked")
    }
    
    @objc func toggleSwitcher() {
        print("MenuBarHandler : Toggle switcher")
        FloatingPanelHandler.shared.togglePanel()
    }
}
