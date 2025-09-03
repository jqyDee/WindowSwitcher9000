//
//  FloatingPanel.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import AppKit
import SwiftUI

// MARK: - Floating Panel

final class FloatingPanel<Content: View>: NSPanel {
    private let didClose: () -> Void
    
    init(
        view: () -> Content,
        contentRect: NSRect,
        didClose: @escaping () -> Void
    ) {
        self.didClose = didClose
        
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        configureAppearance()
        configureBehavior()
        configureControls()
        
        contentView = NSHostingView(rootView: view())
    }
    
    // MARK: - Configuration
    
    private func configureAppearance() {
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        styleMask.remove(.titled)
        isMovableByWindowBackground = true
    }
    
    private func configureBehavior() {
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hidesOnDeactivate = true
        animationBehavior = .utilityWindow
    }
    
    private func configureControls() {
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    // MARK: - Overrides
    
    /// Close automatically when out of focus
    override func resignKey() {
        super.resignKey()
        close()
    }
    
    /// Ensure `didClose` is triggered
    override func close() {
        super.close()
        didClose()
    }
    
    /// Allow focus inside (for text fields, etc.)
    override var canBecomeKey: Bool { true }
    
    /// Prevent stealing "main" focus from the active app
    override var canBecomeMain: Bool { false }
}
