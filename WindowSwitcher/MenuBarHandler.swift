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
    
    @AppStorage("DockHidden") private var isDockHidden: Bool = true

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
        isDockHidden.toggle()
        if isDockHidden {
            NSApp.setActivationPolicy(.accessory)  // hide Dock
        } else {
            NSApp.setActivationPolicy(.regular)   // show Dock
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func quit() {
        print("MenuBarHandler : Quitting")
        NSApp.terminate(nil)
    }
    
    @objc func requestAccessibilityPermission(_ sender: NSMenuItem) {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true]
        _ = AXIsProcessTrustedWithOptions(options)
        
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            sender.state = self.checkAccessibilityPermission() ? .on : .off
        }
    }
    
    @objc func checkAccessibilityPermission() -> Bool {
        return AXIsProcessTrusted()
    }
    
    @objc func updateScreenRecordingMenuItem(_ sender: NSMenuItem) {
        let granted = CGPreflightScreenCaptureAccess()
        sender.state = granted ? .on : .off
        print("Screen Recording permission: \(granted)")
    }
    
    @objc func openHotkeyPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 100)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: SettingsView())
        
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    @objc func togglePreview(_ sender: NSMenuItem) {
        let newState = !(UserDefaults.standard.bool(forKey: "PreviewEnabled"))
        UserDefaults.standard.set(newState, forKey: "PreviewEnabled")
        sender.state = newState ? .on : .off
        print("MenuBarHandler : Preview is now \(newState ? "enabled" : "disabled")")
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
            key: "o"
        ))
        
        menu.addItem(.separator())
        
        menu.addItem(makeMenuItem(
            title: "Show Menu Bar Icon",
            action: #selector(hideBarIcon)
        ))
        
        let dockItem = NSMenuItem(
            title: "Hide Dock Icon",
            action: #selector(toggleDockIcon),
            keyEquivalent: ""
        )
        dockItem.target = self
        dockItem.state = isDockHidden ? .on : .off
        menu.addItem(dockItem)

        
        let previewItem = NSMenuItem(
            title: "Show Preview",
            action: #selector(togglePreview),
            keyEquivalent: ""
        )
        previewItem.target = self
        previewItem.state = UserDefaults.standard.bool(forKey: "PreviewEnabled") ? .on : .off
        menu.addItem(previewItem)
        
        menu.addItem(makeMenuItem(
            title: "Set Hotkey",
            action: #selector(openHotkeyPopover)
        ))
        
        menu.addItem(.separator())

        let accessibilityItem = NSMenuItem(
            title: "Accessibility Permission",
            action: #selector(requestAccessibilityPermission),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        accessibilityItem.state = checkAccessibilityPermission() ? .on : .off
        menu.addItem(accessibilityItem)
        
        let screenRecordingItem = NSMenuItem(
            title: "Screen Recording Permission",
            action: #selector(updateScreenRecordingMenuItem(_:)),
            keyEquivalent: ""
        )
        screenRecordingItem.target = self
        screenRecordingItem.state = CGPreflightScreenCaptureAccess() ? .on : .off
        menu.addItem(screenRecordingItem)
        
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
