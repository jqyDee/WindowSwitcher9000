//
//  FocusTextField.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 03.01.26.
//

import SwiftUI
import AppKit

class FocusTextField: NSTextField {
    /// ⌘-chords the field doesn't handle itself; return true if handled.
    var onChord: ((KeyChord) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command), let chord = Self.chord(for: event), onChord?(chord) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private static func chord(for event: NSEvent) -> KeyChord? {
        switch (event.keyCode, event.charactersIgnoringModifiers?.lowercased()) {
        case (36, _), (76, _): return .commandEnter  // Return, keypad Enter
        case (_, ","): return .commandComma
        case (_, "k"): return .commandK
        default: return nil
        }
    }
}
