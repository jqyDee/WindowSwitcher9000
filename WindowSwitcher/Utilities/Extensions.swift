//
//  Extensions.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 15.09.25.
//

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
