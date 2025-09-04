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
    @FocusState var isFocused: Bool

    var onEnter: (() -> Void)?
    var onEscape: (() -> Void)?
    var onTab: (() -> Void)?
    var onShiftTab: (() -> Void)?
    
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = "Find the Program in your mess ..."
        field.delegate = context.coordinator
        field.isBezeled = false
        field.backgroundColor = .clear
        field.font = NSFont.systemFont(ofSize: 20)
        field.focusRingType = .none
        field.target = context.coordinator
        field.action = #selector(context.coordinator.enterPressed)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        if isFocused && nsView.window?.firstResponder != nsView.currentEditor() {
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
            parent.onEnter?()
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
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape?()
                return true
            default:
                return false
            }
        }
    }
}
