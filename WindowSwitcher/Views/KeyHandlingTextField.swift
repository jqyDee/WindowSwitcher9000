//
//  KeyHandlingTextField.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import SwiftUI
import AppKit

struct KeyHandlingTextField: NSViewRepresentable {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    
    /// ↩ and ⌘-chords; return true if handled, otherwise the field applies its default (⌘⌫ deletes the line).
    var onChord: ((KeyChord) -> Bool)?
    var onEscape: (() -> Void)?
    var onTab: (() -> Void)?
    var onShiftTab: (() -> Void)?
    var placeholder = "Find the Program in your mess ..."
    
    func makeNSView(context: Context) -> NSTextField {
        let field = FocusTextField()
        field.delegate = context.coordinator
        field.isBezeled = false
        field.backgroundColor = .clear
        field.font = NSFont.systemFont(ofSize: 20)
        // Brighter than the default placeholder color so it stays readable on the dark-tinted glass
        field.focusRingType = .none
        field.target = context.coordinator
        field.action = #selector(context.coordinator.enterPressed)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // keep the coordinator on the current binding: it changes while the action menu is open
        context.coordinator.parent = self
        if nsView.stringValue != text { nsView.stringValue = text }
        if nsView.placeholderAttributedString?.string != placeholder {
            // Brighter than the default placeholder color so it stays readable on the dark-tinted glass
            nsView.placeholderAttributedString = NSAttributedString(
                string: placeholder,
                attributes: [.font: NSFont.systemFont(ofSize: 20), .foregroundColor: NSColor.secondaryLabelColor]
            )
        }
        
        if let focusField = nsView as? FocusTextField {
            focusField.onChord = onChord
        }
        
        if isFocused.wrappedValue && nsView.window?.firstResponder != nsView.currentEditor() {
            nsView.window?.makeFirstResponder(nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: KeyHandlingTextField

        init(_ parent: KeyHandlingTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                parent.text = field.stringValue
            }
        }

        @objc func enterPressed() {
            _ = parent.onChord?(.enter)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)),
                 #selector(NSResponder.moveDown(_:)):
                parent.onTab?()
                return true
            case #selector(NSResponder.insertBacktab(_:)),
                 #selector(NSResponder.moveUp(_:)):
                parent.onShiftTab?()
                return true
            case #selector(NSResponder.deleteToBeginningOfLine(_:)):
                return parent.onChord?(.commandBackspace) ?? false
            case #selector(NSResponder.cancelOperation(_:)):
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true,
                   parent.onChord?(.shiftEscape) == true {
                    return true
                }
                parent.onEscape?()
                return true
            default:
                return false
            }
        }
    }
}
