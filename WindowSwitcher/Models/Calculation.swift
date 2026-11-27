//
//  Calculation.swift
//  WindowSwitcher
//

import Calculator
import Foundation

public struct Calculation: Codable, Identifiable, Equatable {
    public var id = UUID()
    public let expression: String
    public let result: Double
    public var date = Date.now

    public var formattedResult: String { MathEngine.format(result) }
}
