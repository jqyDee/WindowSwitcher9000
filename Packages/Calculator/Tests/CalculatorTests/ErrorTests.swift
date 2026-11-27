import Testing
@testable import Calculator

@Suite("Rejected input")
struct ErrorTests {
    @Test("Only . is a decimal separator", arguments: [
        Failure("3,5", .unexpectedCharacter(",")), Failure("1,000", .unexpectedCharacter(",")),
        Failure("sqrt(2,3)", .unexpectedCharacter(",")), Failure(",5", .unexpectedCharacter(",")),
    ])
    func commas(_ f: Failure) { expectFailure(f) }

    @Test(arguments: [
        Failure("1.2.3", .invalidNumber("1.2.3")), Failure(".", .invalidNumber(".")), Failure("1..2", .invalidNumber("1..2")),
        Failure("1 . 5", .invalidNumber(".")),
    ])
    func malformedNumbers(_ f: Failure) { expectFailure(f) }

    @Test(arguments: [
        Failure("1 & 2", .unexpectedCharacter("&")), Failure("2×3", .unexpectedCharacter("×")),
        Failure("6÷2", .unexpectedCharacter("÷")), Failure("2²", .unexpectedCharacter("²")),
        Failure("x=2", .unexpectedCharacter("=")), Failure("1=1", .unexpectedCharacter("=")),
        Failure("π", .unexpectedCharacter("π")), Failure("$1", .unexpectedCharacter("$")),
        Failure("٣", .unexpectedCharacter("٣")),
    ])
    func unknownCharacters(_ f: Failure) { expectFailure(f) }

    @Test("Incomplete input, as while typing", arguments: [
        Failure("", .unexpectedEnd), Failure("   ", .unexpectedEnd), Failure("1+", .unexpectedEnd),
        Failure("12*(", .unexpectedEnd), Failure("(1+2", .unexpectedEnd), Failure("-", .unexpectedEnd),
        Failure("2^", .unexpectedEnd), Failure("sqrt", .unexpectedEnd), Failure("sqrt(", .unexpectedEnd),
        Failure("sqrt(4", .unexpectedEnd), Failure("(", .unexpectedEnd),
    ])
    func incomplete(_ f: Failure) { expectFailure(f) }

    @Test(arguments: [
        Failure("1+2)", .unexpectedToken(")")), Failure(")", .unexpectedToken(")")), Failure("()", .unexpectedToken(")")),
        Failure("*2", .unexpectedToken("*")), Failure("2**3", .unexpectedToken("*")), Failure("2^^3", .unexpectedToken("^")),
        Failure("2 3", .unexpectedToken("3")), Failure("(1)2", .unexpectedToken("2")), Failure("pi2", .unexpectedToken("2")),
        Failure("sqrt 4", .unexpectedToken("4")), Failure("sin30", .unexpectedToken("30")),
        Failure("sqrt()", .unexpectedToken(")")), Failure("1e3", .unexpectedToken("3")), Failure("/", .unexpectedToken("/")),
    ])
    func misplacedTokens(_ f: Failure) { expectFailure(f) }

    @Test(arguments: [
        Failure("foo", .unknownIdentifier("foo")), Failure("pie", .unknownIdentifier("pie")),
        Failure("sinx", .unknownIdentifier("sinx")), Failure("2x", .unknownIdentifier("x")),
        Failure("max(1)", .unknownIdentifier("max")),
    ])
    func unknownNames(_ f: Failure) { expectFailure(f) }

    @Test("Results that are not finite numbers", arguments: [
        Failure("1/0", .notFinite), Failure("-1/0", .notFinite), Failure("0/0", .notFinite), Failure("7%0", .notFinite),
        Failure("sqrt(-1)", .notFinite), Failure("ln(0)", .notFinite), Failure("ln(-1)", .notFinite),
        Failure("log(0)", .notFinite), Failure("10^400", .notFinite), Failure("(-8)^(1/3)", .notFinite),
        Failure("tan(90)", .notFinite), Failure("asin(2)", .notFinite), Failure("acos(-1.5)", .notFinite),
        Failure("1/(1-1)", .notFinite), Failure("0*(1/0)", .notFinite),
    ])
    func notFinite(_ f: Failure) { expectFailure(f) }

    @Test func ansWithoutPreviousResult() {
        expectFailure(Failure("ans", .noPreviousResult))
        expectFailure(Failure("1+ans", .noPreviousResult))
    }

    @Test("Every error has a readable message")
    func messages() {
        let errors: [MathError] = [
            .unexpectedCharacter(","), .invalidNumber("1.2.3"), .unexpectedEnd, .unexpectedToken(")"),
            .unknownIdentifier("foo"), .noPreviousResult, .notFinite,
        ]
        for error in errors { #expect(!error.message.isEmpty) }
        #expect(MathError.unexpectedCharacter(",").message == "Unexpected character ','")
    }
}
