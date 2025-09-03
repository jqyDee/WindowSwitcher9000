//
//  FloatingPanelHandler.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import SwiftUI
import AppKit
import KeyboardShortcuts

// MARK: - Floating Panel Handler

final class FloatingPanelHandler {
    static let shared = FloatingPanelHandler()
    
    private let width: CGFloat = 750
    private let height: CGFloat = 300
    
    private var cachedWindows: [Window] = []
    private var lastPanelFrame: NSRect?
    private var panel: NSPanel?
    
    private init() {
        KeyboardShortcuts.onKeyUp(for: .openHotkeyWindow) { [weak self] in
            self?.togglePanel()
        }
    }
    
    // MARK: - Public API
    
    func togglePanel() {
        panel == nil ? openPanel() : closePanel()
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
        let panel = makePanel(with: view, frame: frame)
        
        if lastPanelFrame == nil {
            panel.center()
        }
        
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        
        self.panel = panel
    }
    
    func closePanel() {
        guard let panel else { return }
        
        lastPanelFrame = panel.frame
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.close()
            self.panel = nil
        }
    }
    
    func makePanel(with view: WindowSwitcherView, frame: NSRect) -> FloatingPanel<WindowSwitcherView> {
        let panel = FloatingPanel(
            view: { view },
            contentRect: frame,
            didClose: { [weak self] in self?.panel = nil }
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
