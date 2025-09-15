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
    
    private let width: CGFloat = 900
    private let height: CGFloat = 400
    
    private var cachedWindows: [Window] = []
    private var lastPanelFrame: NSRect?
    
    private var panel: FloatingPanel<WindowSwitcherView>?
    private var vm: WindowSwitcherViewModel?
    
    // Observers
    private var didBecomeActiveObserver: Any?
    private var didResignActiveObserver: Any?
    private var isScheduledToShow = false
    
    private init() {
        KeyboardShortcuts.onKeyUp(for: .openHotkeyWindow) { [weak self] in
            DispatchQueue.main.async { self?.togglePanel() }
        }
    }
    
    // MARK: - Public API
    
    @MainActor
    func togglePanel() {
        if let panel = panel {
            panel.isKeyWindow ? closePanel() : showPanel(panel)
        } else {
            openPanel()
        }
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
    
    private func showPanel(_ panel: NSPanel) {
        guard !panel.isVisible else { return }
        
        if NSApp.isActive {
            showImmediately(panel)
        } else {
            scheduleShowAfterActivation(panel)
        }
    }
    
    private func scheduleShowAfterActivation(_ panel: NSPanel) {
        guard !isScheduledToShow else { return }
        isScheduledToShow = true
        
        NSApp.activate(ignoringOtherApps: true)
        
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.clearDidBecomeActiveObserver()
            self.showImmediately(panel)
        }
        
        // Fallback in case notification is delayed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            if self.isScheduledToShow {
                self.clearDidBecomeActiveObserver()
                self.showImmediately(panel)
            }
        }
    }
    
    private func clearDidBecomeActiveObserver() {
        if let observer = didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            didBecomeActiveObserver = nil
        }
        isScheduledToShow = false
    }
    
    private func showImmediately(_ panel: NSPanel) {
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        
        Task { await vm?.initializeOnOpen() }
        
        // Add resign-active observer only once
        addResignActiveObserver()
    }
    
    private func addResignActiveObserver() {
        // Remove previous observer if any
        if let observer = didResignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        didResignActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
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
        
        // Clean up VM and observers
        if let observer = didResignActiveObserver {
            NotificationCenter.default.removeObserver(observer)
            didResignActiveObserver = nil
        }
    }
    
    private func makePanel(with view: WindowSwitcherView, frame: NSRect) -> FloatingPanel<WindowSwitcherView> {
        let panel = FloatingPanel(
            view: { view },
            contentRect: frame,
            didClose: { /* handled manually */ }
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        style(panel)
        return panel
    }
    
    private func style(_ panel: NSPanel) {
        guard let contentView = panel.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 10
        contentView.layer?.borderWidth = 0.4
        contentView.layer?.borderColor = CGColor(gray: 0.7, alpha: 0.8)
        contentView.layer?.masksToBounds = false
    }
}
