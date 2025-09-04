//
// FloatingPanelHandler.swift
// WindowSwitcher
//
// Created by Matti Fischbach on 02.09.25.
//

import SwiftUI
import AppKit
import KeyboardShortcuts

final class FloatingPanelHandler {
    static let shared = FloatingPanelHandler()
    
    private let width: CGFloat = 750
    private let height: CGFloat = 300
    
    private var cachedWindows: [Window] = []
    private var lastPanelFrame: NSRect?
    private var panel: FloatingPanel<WindowSwitcherView>?
    
    // Activation-wait bookkeeping
    private var activationObserver: Any?
    private var isScheduledToShow = false
    
    private init() {
        KeyboardShortcuts.onKeyUp(for: .openHotkeyWindow) { [weak self] in
            DispatchQueue.main.async { self?.togglePanel() }
        }
    }
    
    // MARK: - Public API
    
    func togglePanel() {
        guard let panel = panel else {
            openPanel()
            return
        }
        
        if panel.isKeyWindow {
            closePanel()
        } else {
            showPanel(panel)
        }
    }
}


// MARK: - Panel Management

private extension FloatingPanelHandler {
    func openPanel() {
        let view = WindowSwitcherView(
            initialWindows: cachedWindows,
            onClose: { [weak self] windows in
                self?.cachedWindows = windows
                self?.closePanel()
            }
        )
        
        let frame = lastPanelFrame ?? NSRect(x: 0, y: 0, width: width, height: height)
        
        // Create panel only once
        if panel == nil {
            panel = makePanel(with: view, frame: frame)
            if lastPanelFrame == nil {
                panel?.center()
            }
        } else {
            // Refresh content if panel already exists
            panel?.contentView = NSHostingView(rootView: view)
        }
        
        if let panel = panel {
            showPanel(panel)
        }
    }
    
    func showPanel(_ panel: NSPanel) {
        // If app is already active, show immediately
        if NSApp.isActive {
            showImmediately(panel)
            return
        }
        
        // Otherwise: activate app, then wait for didBecomeActive (robust) with a fallback
        guard !isScheduledToShow else { return } // already scheduled
        isScheduledToShow = true
        
        NSApp.activate(ignoringOtherApps: true)
        
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.clearActivationObserver()
            self.showImmediately(panel)
        }
        
        // Fallback in case notification doesn't arrive fast enough
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self else { return }
            if self.isScheduledToShow {
                self.clearActivationObserver()
                self.showImmediately(panel)
            }
        }
    }
    
    func clearActivationObserver() {
        if let obs = activationObserver {
            NotificationCenter.default.removeObserver(obs)
            activationObserver = nil
        }
        isScheduledToShow = false
    }
    
    func showImmediately(_ panel: NSPanel) {
        // Ensure panel will appear in the active Space and come to front
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        
        // Bring forward reliably
        panel.alphaValue = 1
        panel.orderFrontRegardless()      // ensures it becomes visible across apps
        panel.makeKey()                   // get keyboard focus for controls
        NSApp.activate(ignoringOtherApps: true) // keep app active
    }
    
    func closePanel() {
        guard let panel else { return }
        lastPanelFrame = panel.frame
        
        // Hide but keep the instance for reuse
        panel.orderOut(nil)
    }
    
    func makePanel(with view: WindowSwitcherView, frame: NSRect) -> FloatingPanel<WindowSwitcherView> {
        let panel = FloatingPanel(
            view: { view },
            contentRect: frame,
            didClose: { /* we manage close ourselves */ }
        )
        
        panel.isOpaque = false
        panel.backgroundColor = .clear
        style(panel)
        
        return panel
    }
    
    func style(_ panel: NSPanel) {
        guard let contentView = panel.contentView else { return }
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 10
        contentView.layer?.borderWidth = 0.4
        contentView.layer?.borderColor = CGColor(gray: 0.7, alpha: 0.8)
        contentView.layer?.masksToBounds = false
    }
}
