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
    var onCommandEnter: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Check for Cmd + ,
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "," {
            onSettings?()
            return true
        }
        // Cmd + Return / keypad Enter
        if event.modifierFlags.contains(.command) && (event.keyCode == 36 || event.keyCode == 76) {
            onCommandEnter?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
