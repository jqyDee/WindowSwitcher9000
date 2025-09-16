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
    private static let SCORE_GAP_LEADING = -0.005
        private static let SCORE_GAP_TRAILING = -0.005
        private static let SCORE_GAP_INNER = -0.01
        private static let SCORE_MATCH_CONSECUTIVE = 1.0
        private static let SCORE_MATCH_SLASH = 0.9
        private static let SCORE_MATCH_WORD = 0.8
        private static let SCORE_MATCH_CAPITAL = 0.7
        private static let SCORE_MATCH_DOT = 0.6

        /// Compute fzy-like score for matching `pattern` against `text`.
        /// Returns nil if pattern does not match as subsequence.
        public static func score(text: String, pattern: String) -> Double? {
            guard !pattern.isEmpty else { return 0 }
            let t = Array(text)
            let p = Array(pattern)

            let n = t.count
            let m = p.count

            // Pattern longer than text → no match
            if m > n { return nil }

            // Memo tables
            var D = Array(repeating: Array(repeating: Double.leastNonzeroMagnitude, count: n), count: m)
            var M = Array(repeating: Array(repeating: Double.leastNonzeroMagnitude, count: n), count: m)

            // Precompute per-character bonuses in text
            var bonuses = Array(repeating: 0.0, count: n)
            var lastChar: Character = "/"
            for i in 0..<n {
                let c = t[i]
                if c == "/" {
                    bonuses[i] = SCORE_MATCH_SLASH
                } else if c == "-" || c == "_" || c == " " {
                    bonuses[i] = SCORE_MATCH_WORD
                } else if c >= "A" && c <= "Z" {
                    bonuses[i] = SCORE_MATCH_CAPITAL
                } else if c == "." {
                    bonuses[i] = SCORE_MATCH_DOT
                } else {
                    bonuses[i] = 0.0
                }
                lastChar = c
            }

            // Dynamic programming
            for i in 0..<m {
                var prevScore: Double = Double.leastNonzeroMagnitude
                for j in 0..<n {
                    if p[i].lowercased() == String(t[j]).lowercased() {
                        let score: Double
                        if i == 0 {
                            // First pattern char
                            score = (j == 0 ? 0 : SCORE_GAP_LEADING * Double(j)) + bonuses[j]
                        } else if j > 0 {
                            score = max(
                                M[i - 1][j - 1] + bonuses[j],
                                D[i - 1][j - 1] + SCORE_MATCH_CONSECUTIVE
                            )
                        } else {
                            score = Double.leastNonzeroMagnitude
                        }
                        D[i][j] = score
                        M[i][j] = max(score, prevScore + SCORE_GAP_INNER)
                        prevScore = M[i][j]
                    } else {
                        D[i][j] = Double.leastNonzeroMagnitude
                        M[i][j] = prevScore + (i == m - 1 ? SCORE_GAP_TRAILING : SCORE_GAP_INNER)
                        prevScore = M[i][j]
                    }
                }
            }

            let result = M[m - 1][n - 1]
            return result == Double.leastNonzeroMagnitude ? nil : result
        }
    }
