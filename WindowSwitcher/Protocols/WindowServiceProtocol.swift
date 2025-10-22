//
//  WindowServiceProtocol.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 22.10.25.
//


public protocol WindowServiceProtocol {
    func queryWindows() async throws -> [Window]
    func focus(space: Int, windowId: String) async throws
    func focusFast(space: Int, windowId: String)
}
