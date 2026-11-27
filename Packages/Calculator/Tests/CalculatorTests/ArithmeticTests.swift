import Foundation
import Testing
@testable import Calculator

@Suite("Numbers")
struct NumberTests {
    @Test(arguments: [
        Case("0", 0), Case("42", 42), Case("007", 7), Case("3.14", 3.14),
        Case(".5", 0.5), Case("5.", 5), Case("0.000001", 0.000001),
        Case("123456789012", 123456789012), Case("  7  ", 7), Case("\t1\t+\t1\t", 2),
    ])
    func literals(_ c: Case) { expectValue(c) }
}

@Suite("Operators and precedence")
struct PrecedenceTests {
    @Test(arguments: [
        Case("1+2", 3), Case("5-8", -3), Case("6*7", 42), Case("1/2", 0.5), Case("1/4", 0.25),
        Case("1+2*3", 7), Case("(1+2)*3", 9), Case("12*(3+4)", 84), Case("10-4-3", 3),
        Case("100/10/5", 2), Case("2*3+4*5", 26), Case("2+3*4-5", 9), Case("8/4*2", 4),
        Case("8/(4*2)", 1), Case("1-(2-3)", 2), Case("((((1))))", 1), Case("(1+(2*(3+(4))))", 15),
        Case("0.1+0.2", 0.1 + 0.2), Case("1.5*4", 6), Case("10/4", 2.5),
    ])
    func binary(_ c: Case) { expectValue(c) }

    @Test(arguments: [
        Case("-3", -3), Case("+3", 3), Case("--3", 3), Case("---3", -3), Case("-+-3", 3),
        Case("-(2+3)", -5), Case("2*-3", -6), Case("2--3", 5), Case("2+-3", -1), Case("-2*-2", 4),
        Case("-0", 0),
    ])
    func unary(_ c: Case) { expectValue(c) }

    @Test("Power binds tighter than unary minus and is right-associative", arguments: [
        Case("2^10", 1024), Case("2^3^2", 512), Case("(2^3)^2", 64), Case("-2^2", -4), Case("(-2)^2", 4),
        Case("2^-2", 0.25), Case("-2^-2", -0.25), Case("2^-1^2", 0.5), Case("2*3^2", 18), Case("2^2*3", 12),
        Case("(2*3)^2", 36), Case("8^(1/3)", 2), Case("4^0.5", 2), Case("0^0", 1), Case("5^0", 1),
        Case("1.5^2", 2.25), Case("(-8)^3", -512), Case("10^-3", 0.001),
    ])
    func power(_ c: Case) { expectValue(c) }

    @Test("Modulo truncates toward zero, like the remainder operator", arguments: [
        Case("7%3", 1), Case("-7%3", -1), Case("7%-3", 1), Case("6%3", 0), Case("5.5%2", 1.5),
        Case("2+7%3", 3), Case("2*7%3", 2), Case("7%3*2", 2), Case("2^3%5", 3),
    ])
    func modulo(_ c: Case) { expectValue(c) }

    @Test("Implicit multiplication has the precedence of * and groups left to right", arguments: [
        Case("2pi", 2 * Double.pi), Case("2 pi", 2 * Double.pi), Case("3(4+1)", 15), Case("(1+2)(3+4)", 21),
        Case("2sqrt(16)", 8), Case("pi(2)", 2 * Double.pi), Case("2e", 2 * M_E), Case("-2pi", -2 * Double.pi),
        Case("6/2(3)", 9), Case("1+2(3)", 7), Case("2^2pi", 4 * Double.pi), Case("2pi^2", 2 * Double.pi * Double.pi),
        Case("(2)(3)(4)", 24), Case("2(3)%4", 2), Case("pi e", Double.pi * M_E),
    ])
    func implicitMultiplication(_ c: Case) { expectValue(c) }
}
