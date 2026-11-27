import Foundation
import Testing
@testable import Calculator

/// Randomly generated expression trees, rendered to text and parsed back. The tree's own evaluation
/// is the oracle, so these check parsing (precedence, associativity, parentheses) at scale.
@Suite("Randomized expressions")
struct RandomizedTests {
    indirect enum Node {
        case number(Int)
        case negate(Node)
        case binary(Character, Node, Node)

        var value: Double {
            switch self {
            case .number(let n): return Double(n)
            case .negate(let n): return -n.value
            case .binary(let op, let l, let r):
                switch op {
                case "+": return l.value + r.value
                case "-": return l.value - r.value
                case "*": return l.value * r.value
                default: return l.value / r.value
                }
            }
        }

        /// Fully parenthesized, with `.0` literals so NSExpression does floating-point division.
        var parenthesized: String {
            switch self {
            case .number(let n): return "\(n).0"
            case .negate(let n): return "(-\(n.parenthesized))"
            case .binary(let op, let l, let r): return "(\(l.parenthesized) \(op) \(r.parenthesized))"
            }
        }

        /// Only the parentheses precedence requires, so the parser has to get precedence right.
        var minimal: String { render(parentPrecedence: 0, isRightOperand: false) }

        private func render(parentPrecedence: Int, isRightOperand: Bool) -> String {
            switch self {
            case .number(let n):
                return "\(n)"
            case .negate(let n):
                // unary minus binds tighter than * and /, so only negations of binaries need parentheses
                return "-" + n.render(parentPrecedence: 3, isRightOperand: false)
            case .binary(let op, let l, let r):
                let precedence = op == "+" || op == "-" ? 1 : 2
                let text = l.render(parentPrecedence: precedence, isRightOperand: false) + "\(op)"
                    + r.render(parentPrecedence: precedence, isRightOperand: true)
                // left-associative: an equal-precedence right operand keeps its parentheses
                let needsParentheses = precedence < parentPrecedence || (precedence == parentPrecedence && isRightOperand)
                return needsParentheses ? "(\(text))" : text
            }
        }
    }

    /// Deterministic generator, so a failure reproduces.
    struct SplitMix64: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    static func tree(depth: Int, operators: [Character], using rng: inout SplitMix64) -> Node {
        let roll = Int.random(in: 0..<10, using: &rng)
        if depth == 0 || roll < 2 { return .number(Int.random(in: 0...99, using: &rng)) }
        if roll == 2 { return .negate(tree(depth: depth - 1, operators: operators, using: &rng)) }
        return .binary(
            operators.randomElement(using: &rng)!,
            tree(depth: depth - 1, operators: operators, using: &rng),
            tree(depth: depth - 1, operators: operators, using: &rng)
        )
    }

    @Test("Minimal parentheses parse to the same tree (integer +, -, *: exact)")
    func precedenceIsExact() throws {
        var rng = SplitMix64(state: 1)
        for _ in 0..<2_000 {
            let node = Self.tree(depth: 5, operators: ["+", "-", "*"], using: &rng)
            #expect(try MathEngine.evaluate(node.minimal) == node.value, "\(node.minimal)")
            #expect(try MathEngine.evaluate(node.parenthesized) == node.value, "\(node.parenthesized)")
        }
    }

    @Test("Division included: matches the tree and NSExpression")
    func matchesNSExpression() throws {
        var rng = SplitMix64(state: 2)
        var checked = 0
        while checked < 1_000 {
            let node = Self.tree(depth: 4, operators: ["+", "-", "*", "/"], using: &rng)
            guard node.value.isFinite else { continue }
            checked += 1
            let oracle = (NSExpression(format: node.parenthesized).expressionValue(with: nil, context: nil) as! NSNumber).doubleValue
            #expect(isClose(oracle, node.value), "oracle disagrees with tree: \(node.parenthesized)")
            #expect(isClose(try MathEngine.evaluate(node.minimal), node.value), "\(node.minimal)")
            #expect(isClose(try MathEngine.evaluate(node.parenthesized), node.value), "\(node.parenthesized)")
        }
    }

    @Test("Whitespace never changes the result")
    func whitespaceIsIgnored() throws {
        var rng = SplitMix64(state: 3)
        for _ in 0..<500 {
            let node = Self.tree(depth: 4, operators: ["+", "-", "*"], using: &rng)
            // spacing digits apart would make "1 2" (an error by design), so space only around symbols
            let symbolSpaced = node.minimal.replacingOccurrences(of: #"([-+*()])"#, with: " $1 ", options: .regularExpression)
            #expect(try MathEngine.evaluate(symbolSpaced) == node.value, "\(symbolSpaced)")
        }
    }
}
