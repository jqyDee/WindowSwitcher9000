//
//  MenuBarHandler.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import SwiftUI
import AppKit

final class MenuBarHandler {
    static var shared = MenuBarHandler()
    
    private var statusItem: NSStatusItem!
    
    init() {
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        // Create a variable-length status item (icon only)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.offgrid", accessibilityDescription: "Window Switcher")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        
        // Add a menu if you want a dropdown
        let menu = NSMenu()
        
        let openItem = NSMenuItem(
            title: "Toggle Switcher",
            action: #selector(toggleSwitcher),
            keyEquivalent: "o"
        )
        openItem.target = self
        menu.addItem(openItem)
        
        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: "s"
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(.separator())
        
        let removeMenuItem = NSMenuItem(
            title: "Hide Menu Bar Icon",
            action: #selector(hideBarIcon),
            keyEquivalent: ""
        )
        removeMenuItem.target = self
        menu.addItem(removeMenuItem)
        
        menu .addItem(.separator())
        
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func statusItemClicked() {
        print("menu bar       : Status bar icon clicked")
    }
    
    @objc private func toggleSwitcher() {
        print("menu bar       : toggle switch")
        FloatingPanelHandler.shared.togglePanel()
    }
    
    @objc private func openSettings() {
        print("menu bar       : open settings")
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
    
    @objc func hideBarIcon() {
        statusItem.isVisible = false
    }
    
    @objc func showBarIcon() {
        statusItem.isVisible = true
    }
    
    @objc private func quit() {
        print("menu bar       : quitting")
        NSApp.terminate(nil)
    }
}
