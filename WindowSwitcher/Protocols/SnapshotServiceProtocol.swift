//
//  SnapshotServiceProtocol.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 22.10.25.
//

import AppKit


public protocol SnapshotServiceProtocol {
    @MainActor
    func snapshot(window: Window) async throws -> NSImage
}
