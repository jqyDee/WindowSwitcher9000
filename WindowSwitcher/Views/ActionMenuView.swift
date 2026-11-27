//
//  ActionMenuView.swift
//  WindowSwitcher
//
//  The ⌘K menu: the actions available for the current input, each with its key.
//  Typing filters it (shown in its bottom search line); ↑/↓ select, ↩ runs, Esc closes.
//

import SwiftUI

struct ActionMenuView: View {
    let actions: [PanelAction]
    /// What the user typed to filter; the keys go to the panel's hidden search field.
    let filter: String
    let selection: Int
    let onRun: (PanelAction) -> Void

    private let width: CGFloat = 340
    private let cornerRadius: CGFloat = 16
    private let padding: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Actions")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

            if actions.isEmpty {
                Text("No matching actions")
                    .foregroundStyle(.secondary)
                    .italic()
                    .padding(10)
            }
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                row(action, isSelected: index == selection)
                    .onTapGesture { onRun(action) }
            }

            Divider()
                .padding(.vertical, 4)
            searchLine
        }
        .padding(padding)
        .frame(width: width)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
    }

    private var searchLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            HStack(spacing: 1) {
                if !filter.isEmpty {
                    Text(filter).lineLimit(1)
                }
                // stands in for the hidden field's cursor
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 16)
                if filter.isEmpty {
                    Text("Search actions…").foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
    }

    private func row(_ action: PanelAction, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: action.icon)
                .font(.system(size: 14))
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(action.title)
                .lineLimit(1)
            Spacer(minLength: 16)
            KeyCaps(action.keyLabel)
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(
            // concentric with the menu's corners
            RoundedRectangle(cornerRadius: cornerRadius - padding, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
    }
}

/// A key or chord drawn as key caps, one per key: "⌘↩" becomes ⌘ and ↩, "Esc" stays one cap.
struct KeyCaps: View {
    let keys: [String]

    init(_ label: String) {
        // modifiers each get their own cap; the rest of the label is the key itself
        let modifiers = label.prefix { "⌘⇧⌥⌃".contains($0) }
        let key = label.dropFirst(modifiers.count)
        keys = modifiers.map(String.init) + (key.isEmpty ? [] : [String(key)])
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 24, minHeight: 22)
                    .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }
}
