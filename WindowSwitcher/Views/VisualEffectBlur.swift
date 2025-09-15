//
//  VisualEffectBlur.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//

import SwiftUI

public struct VisualEffectBlur: NSViewRepresentable {
    var darkeningOpacity: CGFloat = 0.4

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .sidebar
        view.state = .active
        
        let darkOverlay = NSView()
        darkOverlay.wantsLayer = true
        darkOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(darkeningOpacity).cgColor
        darkOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(darkOverlay)
        
        NSLayoutConstraint.activate([
            darkOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            darkOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            darkOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            darkOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.subviews.first?.layer?.backgroundColor =
            NSColor.black.withAlphaComponent(darkeningOpacity).cgColor
    }
}
