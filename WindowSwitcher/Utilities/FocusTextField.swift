//
//  FocusTextField.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 03.01.26.
//

import SwiftUI
import AppKit

class FocusTextField: NSTextField {
    var onSettings: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Check for Cmd + ,
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "," {
            onSettings?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
