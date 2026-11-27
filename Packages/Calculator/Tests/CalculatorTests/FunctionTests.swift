import Foundation
import Testing
@testable import Calculator

@Suite("Functions and constants")
struct FunctionTests {
    @Test(arguments: [
        Case("sqrt(16)", 4), Case("sqrt(2)", 2.0.squareRoot()), Case("sqrt(0)", 0), Case("sqrt(sqrt(16))", 2),
        Case("abs(-4)", 4), Case("abs(4)", 4), Case("abs(-2.5)", 2.5),
        Case("ln(e)", 1), Case("ln(1)", 0), Case("ln(e^3)", 3),
        Case("log(1000)", 3), Case("log(1)", 0), Case("log(0.01)", -2),
        Case("floor(1.5)", 1), Case("floor(-1.5)", -2), Case("ceil(1.2)", 2), Case("ceil(-1.5)", -1),
        Case("sqrt(9)+sqrt(16)", 7), Case("2^sqrt(4)", 4), Case("sqrt(2)^2", 2), Case("-sqrt(4)", -2),
    ])
    func general(_ c: Case) { expectValue(c) }

    @Test("round rounds halves away from zero", arguments: [
        Case("round(2.5)", 3), Case("round(-2.5)", -3), Case("round(2.4)", 2), Case("round(-2.4)", -2),
        Case("round(0.5)", 1),
    ])
    func round(_ c: Case) { expectValue(c) }

    @Test("Trigonometry is in degrees and exact at multiples of 90°", arguments: [
        Case("sin(0)", 0), Case("sin(30)", 0.5), Case("sin(45)", 0.5.squareRoot()), Case("sin(60)", 3.0.squareRoot() / 2),
        Case("sin(90)", 1), Case("sin(180)", 0), Case("sin(270)", -1), Case("sin(360)", 0), Case("sin(-30)", -0.5),
        Case("sin(390)", 0.5), Case("sin(720)", 0),
        Case("cos(0)", 1), Case("cos(60)", 0.5), Case("cos(90)", 0), Case("cos(180)", -1), Case("cos(270)", 0),
        Case("cos(-60)", 0.5),
        Case("tan(0)", 0), Case("tan(45)", 1), Case("tan(135)", -1), Case("tan(-45)", -1), Case("tan(180)", 0),
        Case("tan(60)", 3.0.squareRoot()),
        Case("asin(0.5)", 30), Case("asin(1)", 90), Case("asin(-1)", -90), Case("acos(0.5)", 60), Case("acos(-1)", 180),
        Case("acos(1)", 0), Case("atan(1)", 45), Case("atan(-1)", -45), Case("atan(0)", 0),
        Case("sin(asin(0.3))", 0.3), Case("asin(sin(40))", 40), Case("sin(30)^2+cos(30)^2", 1),
    ])
    func trigonometry(_ c: Case) { expectValue(c) }

    @Test("Names are case-insensitive", arguments: [
        Case("SIN(30)", 0.5), Case("Sqrt(9)", 3), Case("PI", Double.pi), Case("E", M_E),
    ])
    func caseInsensitive(_ c: Case) { expectValue(c) }

    @Test(arguments: [Case("pi", Double.pi), Case("e", M_E), Case("2*pi", 2 * Double.pi), Case("e^2", M_E * M_E)])
    func constants(_ c: Case) { expectValue(c) }

    @Test(arguments: [
        Case("ans", 42), Case("ans*2", 84), Case("ans+ans", 84), Case("2ans", 84), Case("ans/6", 7),
    ])
    func ans(_ c: Case) { expectValue(c, ans: 42) }

    @Test("ans is a single value, so powers apply to all of it and unary minus to its result")
    func negativeAns() {
        expectValue(Case("ans^2", 9), ans: -3)
        expectValue(Case("-ans", 3), ans: -3)
        expectValue(Case("-ans^2", -9), ans: -3)
    }
}
