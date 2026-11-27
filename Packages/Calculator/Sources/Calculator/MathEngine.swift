//
//  MathEngine.swift
//  Calculator
//
//  Evaluates calculator input typed after `$`.
//
//  Grammar (lowest to highest precedence):
//    expr    := term (('+' | '-') term)*
//    term    := unary (('*' | '/' | '%') unary | implicit)*   implicit: `2pi`, `3(4+1)`, `2sqrt(4)`
//    unary   := ('+' | '-') unary | power
//    power   := primary ('^' unary)?                           right-associative, so -2^2 = -4
//    primary := number | constant | function '(' expr ')' | '(' expr ')'
//
//  Only `.` is a decimal separator; `,` is rejected. Trigonometry works in degrees.
//

import Foundation

public enum MathError: Error, Equatable {
    case unexpectedCharacter(Character)
    case invalidNumber(String)
    case unexpectedEnd
    case unexpectedToken(String)
    case unknownIdentifier(String)
    case noPreviousResult
    case notFinite

    public var message: String {
        switch self {
        case .unexpectedCharacter(let c): return "Unexpected character '\(c)'"
        case .invalidNumber(let s): return "Invalid number '\(s)'"
        case .unexpectedEnd: return "Incomplete expression"
        case .unexpectedToken(let t): return "Unexpected '\(t)'"
        case .unknownIdentifier(let s): return "Unknown name '\(s)'"
        case .noPreviousResult: return "No previous result for 'ans'"
        case .notFinite: return "Result is not a finite number"
        }
    }
}

public enum MathEngine {
    /// Evaluates `expression`. `ans` is the value of the `ans` constant (the last result), if any.
    public static func evaluate(_ expression: String, ans: Double? = nil) throws -> Double {
        var parser = Parser(tokens: try tokenize(expression), ans: ans)
        let value = try parser.parseExpression()
        if let extra = parser.peek { throw MathError.unexpectedToken(extra.description) }
        guard value.isFinite else { throw MathError.notFinite }
        return value
    }

    /// Formats a result with up to 12 significant digits, so `0.1+0.2` shows as `0.3`.
    public static func format(_ value: Double) -> String {
        let s = String(format: "%.12g", value)
        return s == "-0" ? "0" : s
    }

    // MARK: - Tokens

    enum Token: Equatable, CustomStringConvertible {
        case number(Double)
        case identifier(String)
        case symbol(Character)

        var description: String {
            switch self {
            case .number(let v): return MathEngine.format(v)
            case .identifier(let s): return s
            case .symbol(let c): return String(c)
            }
        }
    }

    static func tokenize(_ input: String) throws -> [Token] {
        var tokens: [Token] = []
        var i = input.startIndex
        while i < input.endIndex {
            let c = input[i]
            if c.isWhitespace {
                i = input.index(after: i)
            } else if c.isASCII && (c.isNumber || c == ".") {
                let start = i
                while i < input.endIndex, input[i].isASCII, input[i].isNumber || input[i] == "." {
                    i = input.index(after: i)
                }
                let text = String(input[start..<i])
                guard let value = Double(text) else { throw MathError.invalidNumber(text) }
                tokens.append(.number(value))
            } else if c.isASCII && c.isLetter {
                let start = i
                while i < input.endIndex, input[i].isASCII, input[i].isLetter {
                    i = input.index(after: i)
                }
                tokens.append(.identifier(input[start..<i].lowercased()))
            } else if "+-*/^%()".contains(c) {
                tokens.append(.symbol(c))
                i = input.index(after: i)
            } else {
                throw MathError.unexpectedCharacter(c)
            }
        }
        return tokens
    }

    // MARK: - Names

    private static let degree = Double.pi / 180

    static let functions: [String: @Sendable (Double) -> Double] = [
        "sqrt": { $0.squareRoot() },
        "abs": { abs($0) },
        "ln": { Foundation.log($0) },
        "log": { log10($0) },
        "round": { $0.rounded() },
        "floor": { Foundation.floor($0) },
        "ceil": { Foundation.ceil($0) },
        // the *pi variants are exact at multiples of 90°, so sin(180) is 0, not 1.2e-16
        "sin": { __sinpi($0 / 180) },
        "cos": { __cospi($0 / 180) },
        "tan": { __tanpi($0 / 180) },
        "asin": { Foundation.asin($0) / degree },
        "acos": { Foundation.acos($0) / degree },
        "atan": { Foundation.atan($0) / degree },
    ]

    // MARK: - Parser

    struct Parser {
        let tokens: [Token]
        let ans: Double?
        var position = 0

        var peek: Token? { position < tokens.count ? tokens[position] : nil }

        mutating func next() throws -> Token {
            guard let token = peek else { throw MathError.unexpectedEnd }
            position += 1
            return token
        }

        mutating func expect(_ symbol: Character) throws {
            let token = try next()
            guard token == .symbol(symbol) else { throw MathError.unexpectedToken(token.description) }
        }

        mutating func parseExpression() throws -> Double {
            var value = try parseTerm()
            while case .symbol(let op)? = peek, op == "+" || op == "-" {
                position += 1
                let rhs = try parseTerm()
                value = op == "+" ? value + rhs : value - rhs
            }
            return value
        }

        mutating func parseTerm() throws -> Double {
            var value = try parseUnary()
            while let token = peek {
                switch token {
                case .symbol(let op) where op == "*" || op == "/" || op == "%":
                    position += 1
                    let rhs = try parseUnary()
                    switch op {
                    case "*": value *= rhs
                    case "/": value /= rhs
                    default: value = value.truncatingRemainder(dividingBy: rhs)
                    }
                case .identifier, .symbol("("):
                    // implicit multiplication; a bare number after a value (`2 3`) stays an error
                    value *= try parsePower()
                default:
                    return value
                }
            }
            return value
        }

        mutating func parseUnary() throws -> Double {
            if case .symbol(let op)? = peek, op == "-" || op == "+" {
                position += 1
                let operand = try parseUnary()
                return op == "-" ? -operand : operand
            }
            return try parsePower()
        }

        mutating func parsePower() throws -> Double {
            let base = try parsePrimary()
            if peek == .symbol("^") {
                position += 1
                return pow(base, try parseUnary())
            }
            return base
        }

        mutating func parsePrimary() throws -> Double {
            let token = try next()
            switch token {
            case .number(let value):
                return value
            case .symbol("("):
                let value = try parseExpression()
                try expect(")")
                return value
            case .identifier(let name):
                if let function = MathEngine.functions[name] {
                    try expect("(")
                    let argument = try parseExpression()
                    try expect(")")
                    return function(argument)
                }
                switch name {
                case "pi": return .pi
                case "e": return M_E
                case "ans":
                    guard let ans else { throw MathError.noPreviousResult }
                    return ans
                default: throw MathError.unknownIdentifier(name)
                }
            default:
                throw MathError.unexpectedToken(token.description)
            }
        }
    }
}
