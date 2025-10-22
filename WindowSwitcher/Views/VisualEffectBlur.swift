//
//  VisualEffectBlur.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//

import SwiftUI

public struct VisualEffectBlur: NSViewRepresentable {
    // The opacity passed to the view (e.g., from WindowSwitcherView)
    var baseDarkeningOpacity: CGFloat
    
    // Read the system's current color scheme
    @Environment(\.colorScheme) var colorScheme

    // Add initializer to make the property configurable
    public init(darkeningOpacity: CGFloat = 0.4) {
        self.baseDarkeningOpacity = darkeningOpacity
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        // Use a material designed for temporary, floating panels
        view.material = .popover
        view.state = .active
        
        let darkOverlay = NSView()
        darkOverlay.wantsLayer = true
        darkOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(darkOverlay)
        
        NSLayoutConstraint.activate([
            darkOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            darkOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            darkOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            darkOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // Initial setup of overlay color
        updateOverlayColor(nsView: view, colorScheme: colorScheme)
        
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // This is called when the environment or view properties change (e.g., colorScheme switches)
        updateOverlayColor(nsView: nsView, colorScheme: colorScheme)
    }
    
    // Helper function to calculate the adaptive overlay color and opacity
    private func updateOverlayColor(nsView: NSVisualEffectView, colorScheme: ColorScheme) {
        let isDark = colorScheme == .dark
        
        var overlayColor: NSColor
        // We revert to NSColor.black to maintain a dark panel appearance.
        if isDark {
            overlayColor = NSColor.black
        } else {
            overlayColor = NSColor.white
        }

        // Dynamic opacity adjustment for a consistently dark panel:
        // - In Light Mode (base is light, needs strong darkening): Factor is 1.0.
        // - In Dark Mode (base is dark, needs gentle refinement/darkening): Factor is 0.35.
        let opacityFactor: CGFloat = isDark ? 0.35 : 1.0
        
        let finalOpacity = baseDarkeningOpacity * opacityFactor
        
        if let overlay = nsView.subviews.first {
            overlay.layer?.backgroundColor = overlayColor.withAlphaComponent(finalOpacity).cgColor
        }
    }
}
