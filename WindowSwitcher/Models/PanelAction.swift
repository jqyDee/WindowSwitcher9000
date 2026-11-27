//
//  PanelAction.swift
//  WindowSwitcher
//
//  Actions the panel offers in the action menu (⌘K), with the keys that run them.
//  `WindowSwitcherViewModel.availableActions` decides which apply right now;
//  key presses and the menu both run them through `perform(_:)`.
//

/// A key combination the search field reports to the view model.
public enum KeyChord: Hashable {
    case enter
    case commandEnter
    case commandBackspace
    case commandComma
    case commandK
    case shiftEscape

    public var symbol: String {
        switch self {
        case .enter: return "↩"
        case .commandEnter: return "⌘↩"
        case .commandBackspace: return "⌘⌫"
        case .commandComma: return "⌘,"
        case .commandK: return "⌘K"
        case .shiftEscape: return "⇧Esc"
        }
    }
}

public struct PanelAction: Identifiable, Equatable {
    public enum Kind: Hashable {
        case switchToWindow, openApp
        case enterMathMode, calculate, insertEntry, copyResult
        case enterClipboardMode, copyClip
        case deleteEntry, leaveMode
        case clearInput, settings, closePanel
        case toggleDockIcon, toggleDebugMode, quit
    }

    public let kind: Kind
    public let title: String
    public let icon: String
    /// The chord that runs it from the search field, if it has one.
    public let chord: KeyChord?
    /// Shown in the menu: the chord's symbol, or how the action is reached otherwise (e.g. typing `$`);
    /// empty when it has no key.
    public let keyLabel: String

    public var id: Kind { kind }

    init(_ kind: Kind, _ title: String, icon: String, chord: KeyChord) {
        self.kind = kind
        self.title = title
        self.icon = icon
        self.chord = chord
        self.keyLabel = chord.symbol
    }

    init(_ kind: Kind, _ title: String, icon: String, keyLabel: String) {
        self.kind = kind
        self.title = title
        self.icon = icon
        self.chord = nil
        self.keyLabel = keyLabel
    }
}
