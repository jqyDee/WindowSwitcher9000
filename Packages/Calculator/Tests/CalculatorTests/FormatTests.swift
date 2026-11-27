import Testing
@testable import Calculator

@Suite("Result formatting")
struct FormatTests {
    @Test(arguments: [
        (0.0, "0"), (-0.0, "0"), (42.0, "42"), (-42.0, "-42"), (0.5, "0.5"), (2.5, "2.5"),
        (0.1 + 0.2, "0.3"), (1.0 / 3.0, "0.333333333333"), (2.0 / 3.0, "0.666666666667"),
        (Double.pi, "3.14159265359"), (123456789012.0, "123456789012"),
        // past 12 significant digits, and for very small numbers, %g switches to scientific notation
        (1234567890123.0, "1.23456789012e+12"), (1e15, "1e+15"), (0.0001, "0.0001"), (0.00001, "1e-05"),
        (-1.5e-7, "-1.5e-07"),
    ] as [(Double, String)])
    func format(_ value: Double, _ expected: String) {
        #expect(MathEngine.format(value) == expected)
    }

    @Test("Formatting uses . regardless of the user's locale")
    func decimalPoint() {
        #expect(!MathEngine.format(1.5).contains(","))
    }

    @Test("What the user sees for typical inputs", arguments: [
        ("0.1+0.2", "0.3"), ("1/3", "0.333333333333"), ("sin(30)", "0.5"), ("sin(180)", "0"), ("cos(90)", "0"),
        ("2pi", "6.28318530718"), ("sqrt(2)^2", "2"), ("10/3*3", "10"), ("0.1*3", "0.3"), ("1-0.9", "0.1"),
    ])
    func displayed(_ input: String, _ expected: String) throws {
        #expect(MathEngine.format(try MathEngine.evaluate(input)) == expected)
    }
}

@Suite("Tokenizer")
struct TokenizerTests {
    @Test func tokens() throws {
        #expect(try MathEngine.tokenize("2pi*(3.5-x)") == [
            .number(2), .identifier("pi"), .symbol("*"), .symbol("("), .number(3.5), .symbol("-"),
            .identifier("x"), .symbol(")"),
        ])
        #expect(try MathEngine.tokenize("  ") == [])
        #expect(try MathEngine.tokenize("SQRT") == [.identifier("sqrt")])
    }
}
