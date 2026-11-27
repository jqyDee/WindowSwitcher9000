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

    /// The panel's only input: take the keyboard as soon as it is in a window. On the first open the
    /// panel is shown before SwiftUI has created this field, so nothing else would focus it.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window, window.firstResponder !== self.currentEditor() else { return }
            window.makeFirstResponder(self)
        }
    }

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
