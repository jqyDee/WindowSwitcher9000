//
//  FuzzySearch.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 15.09.25.
//


//
//  FuzzySearch.swift
//  WindowSwitcher
//
//  Created by Copilot on 2025-09-15.
//

import Foundation

public struct FuzzySearch {
    /// Computes a fuzzy score between `text` and `pattern`.
    /// Higher scores mean better matches. Exact substring matches are heavily rewarded.
    /// - Parameters:
    ///   - text: The text to search in.
    ///   - pattern: The pattern to match.
    /// - Returns: An integer score (>= 0).
    public static func score(text: String, pattern: String) -> Int {
        guard !pattern.isEmpty else { return 1000 }
        let t = text.lowercased()
        let p = pattern.lowercased()
        if t.contains(p) { return 10000 }
        var score = 0
        var last = t.startIndex
        var consecutive = 0
        for c in p {
            if let idx = t[last...].firstIndex(of: c) {
                let distance = t.distance(from: last, to: idx)
                if distance == 0 {
                    consecutive += 1
                } else {
                    consecutive = 1
                }
                score += consecutive * 10 - distance
                last = t.index(after: idx)
            } else {
                break
            }
        }
        let words = t.split(separator: " ")
        for w in words where w.hasPrefix(p) {
            score += 50
        }
        return max(score, 0)
    }
}
