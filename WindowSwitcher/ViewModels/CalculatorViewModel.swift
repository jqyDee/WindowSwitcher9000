//
//  CalculatorViewModel.swift
//  WindowSwitcher
//
//  State behind math mode (entered with `$`): the persisted history of
//  calculations, its size limit, and which history entry, if any, is selected.
//  Shared, so the panel and Settings see and change the same history.
//

import Calculator
import AppKit
import Combine

@MainActor
public final class CalculatorViewModel: ObservableObject {
    public static let shared = CalculatorViewModel()

    private static let historyKey = "CalculationHistory"
    private static let historyLimitKey = "CalculationHistoryLimit"
    public static let defaultHistoryLimit = 50
    public static let historyLimitRange = 10...1000

    /// Newest first.
    @Published public private(set) var history: [Calculation] {
        didSet { save() }
    }
    /// Most entries kept; lowering it deletes the oldest entries beyond it.
    @Published public var historyLimit: Int {
        didSet {
            UserDefaults.standard.set(historyLimit, forKey: Self.historyLimitKey)
            if history.count > historyLimit { history = Array(history.prefix(historyLimit)) }
        }
    }
    /// Selected history entry; `nil` means the expression being typed.
    @Published public var selectedIndex: Int? = nil
    /// The entry whose result was just copied, shown as a confirmation until it expires.
    @Published public private(set) var copiedEntry: Calculation? = nil
    private var copiedEntryExpiry: Task<Void, Never>?
    /// The expression last put into the input from history; if the input still equals it, nothing was changed.
    private var recalledExpression: String?

    private init() {
        let data = UserDefaults.standard.data(forKey: Self.historyKey) ?? Data()
        history = (try? JSONDecoder().decode([Calculation].self, from: data)) ?? []
        let storedLimit = UserDefaults.standard.integer(forKey: Self.historyLimitKey)
        historyLimit = storedLimit > 0 ? storedLimit : Self.defaultHistoryLimit
    }

    /// Result of the last calculation, available as `ans`.
    public var ans: Double? { history.first?.result }

    public func evaluate(_ expression: String) -> Result<Double, MathError> {
        Result { try MathEngine.evaluate(expression, ans: ans) }.mapError { $0 as? MathError ?? .notFinite }
    }

    public struct SubmitOutcome {
        /// Footer text: an error, or empty (a copy shows its own confirmation).
        public var feedback = ""
        /// Replacement for the input field; `nil` leaves it unchanged.
        public var newInput: String? = nil
    }

    /// Enter. On the input: records `expression` and copies its result.
    /// On a history entry: records a valid `expression` first, then recalls the entry's expression into the input.
    public func submit(_ expression: String) -> SubmitOutcome {
        guard let index = selectedIndex, let entry = history[safe: index] else {
            return commit(expression)
        }
        // a recalled expression the user didn't edit is already in the history
        if expression.trimmed != recalledExpression,
           !expression.trimmed.isEmpty, case .success(let value) = evaluate(expression) {
            record(expression, value)
        }
        recalledExpression = entry.expression
        return SubmitOutcome(newInput: entry.expression)
    }

    /// ⌘Enter. On a history entry: copies its result only. On the input: same as Enter.
    public func copyResult(_ expression: String) -> SubmitOutcome {
        guard let index = selectedIndex, let entry = history[safe: index] else {
            return commit(expression)
        }
        copy(entry)
        return SubmitOutcome()
    }

    private func commit(_ expression: String) -> SubmitOutcome {
        guard !expression.trimmed.isEmpty else { return SubmitOutcome() }
        switch evaluate(expression) {
        case .success(let value):
            copy(record(expression, value))
            return SubmitOutcome(newInput: "")
        case .failure(let error):
            return SubmitOutcome(feedback: error.message)
        }
    }

    @discardableResult
    private func record(_ expression: String, _ value: Double) -> Calculation {
        let calculation = Calculation(expression: expression.trimmed, result: value)
        history = Array(([calculation] + history).prefix(historyLimit))
        return calculation
    }

    /// ⌘⌫ on a history entry: deletes it and keeps the selection at the same position.
    /// Returns false when no entry is selected, so the key keeps its text-editing meaning.
    @discardableResult
    public func removeSelectedEntry() -> Bool {
        guard let index = selectedIndex, history.indices.contains(index) else { return false }
        history.remove(at: index)
        selectedIndex = history.isEmpty ? nil : min(index, history.count - 1)
        return true
    }

    public func clearHistory() {
        history = []
        selectedIndex = nil
        recalledExpression = nil
    }

    public func moveSelectionForward() {
        guard !history.isEmpty else { return }
        selectedIndex = min((selectedIndex ?? -1) + 1, history.count - 1)
    }

    public func moveSelectionBackward() {
        guard let index = selectedIndex else { return }
        selectedIndex = index == 0 ? nil : index - 1
    }

    private func copy(_ entry: Calculation) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.formattedResult, forType: .string)

        copiedEntry = entry
        copiedEntryExpiry?.cancel()
        copiedEntryExpiry = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            copiedEntry = nil
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: Self.historyKey)
        }
    }
}
