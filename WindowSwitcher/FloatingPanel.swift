import AppKit
import SwiftUI

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
        // CHOICE: move to the active space when shown (do NOT combine with canJoinAllSpaces)
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
        
        // Make key behavior deterministic when we request focus programmatically
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = true
    }
    
    private func configureControls() {
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }
    
    // MARK: - Overrides
    
    /// Allow focus inside (for text fields, etc.)
    override var canBecomeKey: Bool { true }
    
    /// Panels typically shouldn't become main
    override var canBecomeMain: Bool { false }
}
