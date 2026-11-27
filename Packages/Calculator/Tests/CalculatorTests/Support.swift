import Foundation
import Testing
@testable import Calculator

/// An expression and the value it must evaluate to.
struct Case: CustomTestStringConvertible, Sendable {
    let input: String
    let expected: Double
    init(_ input: String, _ expected: Double) {
        self.input = input
        self.expected = expected
    }
    var testDescription: String { "\(input) = \(expected)" }
}

/// An expression and the error it must throw.
struct Failure: CustomTestStringConvertible, Sendable {
    let input: String
    let error: MathError
    init(_ input: String, _ error: MathError) {
        self.input = input
        self.error = error
    }
    var testDescription: String { "\(input) -> \(error)" }
}

/// Relative comparison: results go through transcendental functions, so exact equality is too strict.
func isClose(_ actual: Double, _ expected: Double, tolerance: Double = 1e-12) -> Bool {
    actual == expected || abs(actual - expected) <= tolerance * max(1, abs(expected))
}

func expectValue(_ c: Case, ans: Double? = nil, sourceLocation: SourceLocation = #_sourceLocation) {
    do {
        let actual = try MathEngine.evaluate(c.input, ans: ans)
        #expect(isClose(actual, c.expected), "\(c.input) gave \(actual), expected \(c.expected)",
                sourceLocation: sourceLocation)
    } catch {
        Issue.record("\(c.input) threw \(error), expected \(c.expected)", sourceLocation: sourceLocation)
    }
}

func expectFailure(_ f: Failure, ans: Double? = nil, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(throws: f.error, "\(f.input)", sourceLocation: sourceLocation) {
        try MathEngine.evaluate(f.input, ans: ans)
    }
}
