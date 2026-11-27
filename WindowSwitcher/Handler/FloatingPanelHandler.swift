//
//  FloatingPanelHandler.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import SwiftUI
import AppKit
import KeyboardShortcuts

final class FloatingPanelHandler {
    static let shared = FloatingPanelHandler()
    
    private var width: CGFloat {
        CGFloat(UserDefaults.standard.double(forKey: "PanelWidth")) != 0
        ? CGFloat(UserDefaults.standard.double(forKey: "PanelWidth")) : 900
    }
    
    private var height: CGFloat {
        CGFloat(UserDefaults.standard.double(forKey: "PanelHeight")) != 0
        ? CGFloat(UserDefaults.standard.double(forKey: "PanelHeight")) : 400
    }
    
    private var cachedWindows: [Window] = []
    private var lastPanelFrame: NSRect?
    
    private var panel: FloatingPanel<WindowSwitcherView>?
    private var vm: WindowSwitcherViewModel?
    
    private var didResignKeyObserver: Any?
    
    private init() {
        // KeyboardShortcuts 3.x requires main-actor registration; the action is also delivered on the main actor.
        Task { @MainActor [weak self] in
            KeyboardShortcuts.onKeyUp(for: .openHotkeyWindow) { [weak self] in
                self?.togglePanel()
            }
            KeyboardShortcuts.onKeyUp(for: .openCalculator) { [weak self] in
                self?.togglePanel(directly: .math)
            }
            KeyboardShortcuts.onKeyUp(for: .openClipboardHistory) { [weak self] in
                self?.togglePanel(directly: .clipboard)
            }
        }
    }
    
    // MARK: - Public API
    
    /// The switcher hotkey. A mode opened by its own hotkey belongs to that hotkey, so this always
    /// shows the window list then (switching to it if the panel is open in such a mode).
    @MainActor
    func togglePanel() {
        if vm?.isModeOpenedDirectly == true {
            vm?.exitMode()
            if let panel, panel.isKeyWindow { return }
        }
        if let panel = panel {
            panel.isKeyWindow ? closePanel() : showPanel(panel)
        } else {
            openPanel()
        }
    }

    /// A mode's hotkey: opens the panel directly in that mode; pressed again, closes it and
    /// resets it to the switcher.
    @MainActor
    func togglePanel(directly mode: PanelMode) {
        if let panel, panel.isKeyWindow, vm?.mode == mode, vm?.isModeOpenedDirectly == true {
            vm?.exitMode()
            closePanel()
            return
        }
        if let panel { showPanel(panel) } else { openPanel() }
        vm?.openDirectly(mode)
    }
}

// MARK: - Panel Management

extension FloatingPanelHandler {
    @MainActor
    private func openPanel() {
        let vm = WindowSwitcherViewModel()
        vm.windows = cachedWindows
        vm.loadLaunchableApps()
        self.vm = vm
        
        let view = WindowSwitcherView(vm: vm) // raw view, no modifiers
        let frame = lastPanelFrame ?? NSRect(x: 0, y: 0, width: width, height: height)
        
        if panel == nil {
            panel = makePanel(with: view, frame: frame)
            panel?.center()
        } else {
            // Reuse existing panel
            panel?.contentView = NSHostingView(rootView: view)
        }
        
        showPanel(panel!)
    }
    
    /// Shows the panel without activating this app: the panel is non-activating, so it takes the
    /// keyboard while the app you came from stays frontmost. Closing it hands focus straight back,
    /// and ⌘V after copying from the clipboard history lands in that app.
    private func showPanel(_ panel: NSPanel) {
        guard !panel.isVisible else { return }
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.makeKeyAndOrderFront(nil)

        Task { await vm?.initializeOnOpen() }

        // close when the panel loses the keyboard: a click elsewhere, switching apps, Settings opening
        if let observer = didResignKeyObserver { NotificationCenter.default.removeObserver(observer) }
        didResignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closePanel()
            }
        }
    }

    @MainActor
    func closePanel() {
        guard let panel else { return }
        lastPanelFrame = panel.frame
        
        // Hide panel
        panel.orderOut(nil)
        
        vm?.stopAutoRefresh()
        vm?.closeActionMenu()
        
        if let observer = didResignKeyObserver {
            NotificationCenter.default.removeObserver(observer)
            didResignKeyObserver = nil
        }
    }
    
    private func makePanel(with view: WindowSwitcherView, frame: NSRect) -> FloatingPanel<WindowSwitcherView> {
        let panel = FloatingPanel(
            view: { view },
            contentRect: frame,
            didClose: { /* handled manually */ }
        )
        
        // Fully transparent window: the SwiftUI Liquid Glass shapes draw the visible panel and its shadow.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        return panel
    }
    
    @MainActor
    func resetPanelFrame() {
        closePanel()
        
        panel = nil
        lastPanelFrame = nil
    }
}
