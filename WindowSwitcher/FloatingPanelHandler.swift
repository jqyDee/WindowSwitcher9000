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
    
    private let width: CGFloat = 750
    private let height: CGFloat = 300
    
    var cachedWindows: [Window] = []
    
    private var lastPanelFrame: NSRect?
    private var panel: NSPanel?

    private init() {
        KeyboardShortcuts.onKeyUp(for: .openHotkeyWindow) {
            print("floating panel : keypress")
            FloatingPanelHandler.shared.togglePanel()
        }
    }
    
    func togglePanel() {
        print("floating panel : toggling ")
        if self.panel == nil {
            openPanel()
        } else {
            closePanel()
        }
    }
    
    private func openPanel() {
        print("floating panel : opening ")
        let view = WindowSwitcherView(
            initialWindows: cachedWindows,
            onClose: { [weak self] windows in
                // update cache when panel closes
                self?.cachedWindows = windows
                self?.closePanel()
            }
        )
        
        let frameToUse = lastPanelFrame ?? NSRect(x: 0, y: 0, width: width, height: height)
        
        let panel = FloatingPanel(
            view: {
                view
            },
            contentRect: frameToUse,
            didClose: {
                [weak self] in
                self?.panel = nil
            }
        )
        
        // Make window background transparent so we can clip it
        panel.isOpaque = false
        panel.backgroundColor = .clear

        // Round the actual panel corners
        if let contentView = panel.contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 10
            contentView.layer?.borderWidth = 0.4
            contentView.layer?.borderColor = CGColor(gray: 0.7, alpha: 0.8)
            contentView.layer?.masksToBounds = false
        }
        
        if lastPanelFrame == nil {
            panel.center()
        }
        
        // It's important to activate the NSApplication so that our window
        // shows on top and takes the focus.
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        
        self.panel = panel
    }
    
    private func closePanel() {
        print("floating panel : closing ")
        if let panel = panel {
            lastPanelFrame = panel.frame
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = 0
            } completionHandler: {
                panel.close()
            }
        }
        
        panel = nil
    }
}
