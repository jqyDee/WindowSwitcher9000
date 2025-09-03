//
//  FloatingPanel.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import AppKit
import SwiftUI


final class FloatingPanel<Content: View>: NSPanel {
    init(
        view: () -> Content,
        // We need to provide NSRect since the NSWindow doesn't inherit the size from the content
        // by default. Not setting the contentRect would result in incorrect positioning
        // when centering the window
        contentRect: NSRect,
        didClose: @escaping () -> Void
    ) {
        self.didClose = didClose
        
        super.init(
            contentRect: contentRect,
            styleMask: [
                .titled,
                .closable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        
        /// Allow the panel to be on top of other windows
        isFloatingPanel = true
        level = .floating
        
        /// Allow the pannel to be overlaid in a fullscreen space
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .none
        
        /// Don't show a window title, even if it's set
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        styleMask.remove(.titled)
        
        /// Since there is no title bar make the window moveable by dragging on the background
        isMovableByWindowBackground = true
        
        /// Hide when unfocused
        hidesOnDeactivate = true
        
        /// Hide all traffic light buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        /// Sets animations accordingly
        animationBehavior = .utilityWindow
        
        /// Set the content view.
        /// The safe area is ignored because the title bar still interferes with the geometry
        contentView = NSHostingView(
            rootView: view()
        )
    }
    
    private let didClose: () -> Void
    
    /// Close automatically when out of focus, e.g. outside click
    override func resignKey() {
        super.resignKey()
        close()
    }
    
    /// Close and toggle presentation, so that it matches the current state of the panel
    override func close() {
        super.close()
        didClose()
    }
    
    /// `canBecomeKey` is required so that text inputs inside the panel can receive focus
    override var canBecomeKey: Bool {
        return true
    }
    
    // For our use case, we don't want the window to become main and thus steal the focus from
    // the previously opened app completely
    override var canBecomeMain: Bool {
        return false
    }
}
