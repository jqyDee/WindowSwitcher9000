//
//  CalculatorHistoryView.swift
//  WindowSwitcher
//
//  Math mode's results card: past calculations, newest first.
//

import Calculator
import SwiftUI

struct CalculatorHistoryView: View {
    @ObservedObject var calculator: CalculatorViewModel
    var cornerRadius: CGFloat
    var padding: CGFloat

    var body: some View {
        if calculator.history.isEmpty {
            Text("Type a formula and press Enter to copy the result")
                .foregroundColor(.secondary)
                .italic()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(calculator.history.enumerated()), id: \.element.id) { index, entry in
                            // identity stays the entry's id (from ForEach): keying rows by index
                            // makes the lazy stack keep stale rows when a new entry is prepended
                            row(entry, isSelected: index == calculator.selectedIndex)
                                .onTapGesture { calculator.selectedIndex = index }
                        }
                    }
                }
                .scrollIndicators(.never)
                // margins, not padding: scrollTo keeps rows inside them, so the gap survives scrolling
                .contentMargins(padding, for: .scrollContent)
                .onChange(of: calculator.selectedIndex) { _, index in
                    if let entry = calculator.history[safe: index ?? 0] {
                        proxy.scrollTo(entry.id)
                    }
                }
            }
        }
    }

    private func row(_ entry: Calculation, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Text(entry.expression)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if calculator.copiedEntry?.id == entry.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }
            Text("= \(entry.formattedResult)")
                .font(.headline.monospacedDigit())
                .lineLimit(1)
        }
        .animation(.easeInOut(duration: 0.25), value: calculator.copiedEntry)
        .padding(.horizontal, 14)
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
    }
}

/// Trailing part of the search bar in math mode: the live result of `expression`,
/// or, while nothing evaluable is typed, a clipboard icon confirming the last copy.
struct CalculatorResultLabel: View {
    @ObservedObject var calculator: CalculatorViewModel
    let expression: String

    var body: some View {
        Group {
            if case .success(let value) = calculator.evaluate(expression) {
                Text("= \(MathEngine.format(value))")
                    .foregroundStyle(.secondary)
            } else if calculator.copiedEntry != nil {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .help("Copied to clipboard")
                    .transition(.opacity)
            }
        }
        .font(.system(size: 20, weight: .medium).monospacedDigit())
        .lineLimit(1)
        .fixedSize()
        .animation(.easeInOut(duration: 0.25), value: calculator.copiedEntry)
    }
}
