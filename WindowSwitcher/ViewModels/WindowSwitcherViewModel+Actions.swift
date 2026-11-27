//
//  WindowSwitcherViewModel+Actions.swift
//  WindowSwitcher
//
//  The actions available for the current input, key-chord dispatch, and the ⌘K action menu.
//

import Foundation

extension WindowSwitcherViewModel {
    /// Everything that can be run right now, in menu order. The single source for
    /// what a key chord does and what the action menu lists.
    public var availableActions: [PanelAction] {
        var actions: [PanelAction] = []
        switch inputMode {
        case .windows:
            if let window = displayedWindows[safe: selectedIndex] {
                actions.append(window.pid == 0 || window.isLauncher
                    ? PanelAction(.openApp, "Open App", icon: "arrow.up.forward.app", chord: .enter)
                    : PanelAction(.switchToWindow, "Switch to Window", icon: "macwindow", chord: .enter))
            }
            actions.append(PanelAction(.enterMathMode, "Calculator", icon: "function", keyLabel: "$"))
        case .command:
            actions.append(PanelAction(.runCommand, "Run Command", icon: "terminal", chord: .enter))
        case .math(let expression):
            if calculator.selectedIndex == nil {
                if !expression.trimmed.isEmpty {
                    actions.append(PanelAction(.calculate, "Calculate and Copy", icon: "equal", chord: .enter))
                }
            } else {
                actions.append(PanelAction(.insertEntry, "Insert into Field", icon: "text.insert", chord: .enter))
                actions.append(PanelAction(.copyResult, "Copy Result", icon: "doc.on.clipboard", chord: .commandEnter))
                actions.append(PanelAction(.deleteEntry, "Delete Entry", icon: "trash", chord: .commandBackspace))
            }
        }
        actions.append(PanelAction(.settings, "Settings", icon: "gearshape", chord: .commandComma))
        // Esc (see handleEscape) steps back: it clears the input first, then on an empty field
        // leaves math mode, or closes the panel (which ⇧Esc below does as well).
        if !filterText.isEmpty {
            actions.append(PanelAction(.clearInput, isMathMode ? "Clear Input" : "Clear Search",
                                       icon: "delete.left", keyLabel: "Esc"))
        } else if isMathMode {
            actions.append(PanelAction(.leaveMathMode, "Leave Calculator", icon: "magnifyingglass", keyLabel: "Esc"))
        }
        // closes at once and keeps the input (and math mode) for the next time the panel opens
        actions.append(PanelAction(.closePanel, "Close", icon: "xmark", chord: .shiftEscape))
        return actions
    }

    /// The menu's list: available actions matching the menu filter, best match first
    /// (menu order without a filter, and between equal matches).
    public var menuActions: [PanelAction] {
        let filter = actionFilter.trimmed
        guard !filter.isEmpty else { return availableActions }
        return availableActions.enumerated()
            .filter { FuzzySearch.matches(text: $0.element.title, pattern: filter) }
            .map { (offset: $0.offset, action: $0.element,
                    score: FuzzySearch.score(text: $0.element.title, pattern: filter) ?? 0) }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.offset < $1.offset }
            .map(\.action)
    }

    /// A chord from the search field. Returns false when nothing handles it,
    /// so the field can apply its default (⌘⌫ deletes to the start of the line).
    @discardableResult
    public func handleChord(_ chord: KeyChord) -> Bool {
        if chord == .commandK {
            isActionMenuOpen ? closeActionMenu() : openActionMenu()
            return true
        }
        if isActionMenuOpen, chord == .enter {
            if let action = menuActions[safe: actionSelection] { perform(action) }
            return true
        }
        guard let action = availableActions.first(where: { $0.chord == chord }) else {
            // ⌘↩ without its own action means the same as ↩
            return chord == .commandEnter ? handleChord(.enter) : false
        }
        perform(action)
        return true
    }

    public func perform(_ action: PanelAction) {
        closeActionMenu()
        switch action.kind {
        case .switchToWindow, .openApp, .runCommand, .calculate, .insertEntry:
            handleEnter()
        case .copyResult:
            if case .math(let expression) = inputMode { apply(calculator.copyResult(expression)) }
        case .deleteEntry:
            calculator.removeSelectedEntry()
        case .enterMathMode:
            filterText = "$"
        case .clearInput:
            filterText = ""
        case .leaveMathMode:
            exitMathMode()
        case .settings:
            FloatingPanelHandler.shared.closePanel()
            MenuBarHandler.shared.openSettings()
        case .closePanel:
            FloatingPanelHandler.shared.closePanel()
        }
    }

    // MARK: - Menu

    public func openActionMenu() {
        actionFilter = ""
        actionSelection = 0
        isActionMenuOpen = true
    }

    public func closeActionMenu() {
        isActionMenuOpen = false
        actionFilter = ""
        actionSelection = 0
    }

    func moveActionSelection(by offset: Int) {
        let count = menuActions.count
        guard count > 0 else { return }
        actionSelection = (actionSelection + offset + count) % count
    }
}
