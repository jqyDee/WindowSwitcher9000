//
//  MenuBarHandler.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import SwiftUI
import AppKit
import Darwin
import MachO
import Foundation
import UserNotifications

// MARK: - Menu Bar Handler

class MenuBarHandler {
    static let shared = MenuBarHandler()
    
    @AppStorage("DockHidden") public var isDockHidden: Bool = true

    private var statusItem: NSStatusItem
    
    private var memoryMenuItem: NSMenuItem?
    private var memoryRefresher: AutoRefreshService?
    private var dockMenuItem: NSMenuItem?
    
    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupMenuBar()
        showBarIcon()
        startMemoryMonitoring()
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
    
    func toggleDockIconProgrammatically() {
        isDockHidden.toggle()
        
        if isDockHidden {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        
        // Update menu item if it exists
        dockMenuItem?.state = isDockHidden ? .off : .on
    }
    
    @objc func toggleDockIcon(_ sender: NSMenuItem) {
        toggleDockIconProgrammatically()
        sender.state = isDockHidden ? .off : .on
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
        let granted = AXIsProcessTrusted()
        
        let msg = "Accessibility permission: \(granted)"
        NotificationService.shared.dispatch(title: "Accessibility Permission", message: msg)

        return granted
    }
    
    @objc func checkScreenRecordingPermission() -> Bool {
        let granted = CGPreflightScreenCaptureAccess()
        let msg = "Screen Recording Permission: \(granted)"
        NotificationService.shared.dispatch(title: "Screen Recording Permissions", message: msg)
        
        return granted
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
        
        NotificationService.shared.dispatch(title: "Preview", message: "Preview is now \(newState ? "enabled" : "disabled")")
    }
    
    @objc func resetPanelFrame() {
        Task { @MainActor in
            FloatingPanelHandler.shared.resetPanelFrame()
        }
        NotificationService.shared.dispatch(title: "Panel Location", message: "Panel location has been reset")
    }
    
    @objc func clearHistory() {
        UserDefaults.standard.removeObject(forKey: "SelectionHistory")
        print("MenuBarHandler : Selection history cleared")
        
        NotificationService.shared.dispatch(title: "History Cleared", message: "Search preferences have been reset.")
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
        
        // Memory usage item
        let memItem = NSMenuItem(
            title: "Memory Usage: -- MB",
            action: nil,
            keyEquivalent: ""
        )
        memoryMenuItem = memItem
        menu.addItem(memItem)
        
        menu.addItem(.separator())
        
        menu.addItem(makeMenuItem(
            title: "Hide Menu Bar Icon",
            action: #selector(hideBarIcon)
        ))
        
        let dockItem = NSMenuItem(
            title: "Dock Icon",
            action: #selector(toggleDockIcon(_:)),
            keyEquivalent: ""
        )
        dockItem.target = self
        dockItem.state = isDockHidden ? .off : .on
        menu.addItem(dockItem)
        dockMenuItem = dockItem  // keep reference
        
        let previewItem = NSMenuItem(
            title: "Preview",
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
        
        menu.addItem(makeMenuItem(
            title: "Reset Panel Frame",
            action: #selector(resetPanelFrame)
        ))
        
        menu.addItem(makeMenuItem(
            title: "Clear Selection History",
            action: #selector(clearHistory)
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
            action: #selector(checkScreenRecordingPermission),
            keyEquivalent: ""
        )
        screenRecordingItem.target = self
        screenRecordingItem.state = checkScreenRecordingPermission() ? .on : .off
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
    
    @MainActor @objc func toggleSwitcher() {
        print("MenuBarHandler : Toggle switcher")
        FloatingPanelHandler.shared.togglePanel()
    }
}

// MARK: - Memory

private extension MenuBarHandler {
    func currentMemoryMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<natural_t>.size)
        
        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / 1024.0 / 1024.0
    }
    
    func startMemoryMonitoring(interval: TimeInterval = 5.0) {
        memoryRefresher?.stop()
        let weakSelf = self

        memoryRefresher = AutoRefreshService(interval: interval) { @Sendable in
            Task { @MainActor in
                weakSelf.updateMemoryMenuItem()
            }
        }
        memoryRefresher?.start()
    }
    
    func updateMemoryMenuItem() {
        let memMB = currentMemoryMB()
        memoryMenuItem?.title = String(format: "Memory Usage: %.1f MB", memMB)
    }
}

