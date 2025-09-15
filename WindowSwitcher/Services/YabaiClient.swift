//
//  YabaiError.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//


import Foundation


public enum YabaiError: Error {
    case notFound
    case failed(Int32, Data)
    case decoding(Error)
}

public protocol YabaiServiceProtocol {
    func queryWindows() async throws -> [Window]
    func focus(space: Int, windowId: String) async throws
}

public actor YabaiClient: YabaiServiceProtocol {
    public let yabaiPath: URL

    public init(yabaiPath: String = "/opt/homebrew/bin/yabai") {
        self.yabaiPath = URL(fileURLWithPath: yabaiPath)
    }

    private func run(arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = yabaiPath
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        try process.run()
        process.waitUntilExit()

        let out = outPipe.fileHandleForReading.readDataToEndOfFile()
        let err = errPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            throw YabaiError.failed(process.terminationStatus, err)
        }
        return out
    }

    public func queryWindows() async throws -> [Window] {
        do {
            let data = try run(arguments: ["-m", "query", "--windows"])
            let decoder = JSONDecoder()
            return try decoder.decode([Window].self, from: data)
        } catch let err as YabaiError {
            throw err
        } catch {
            throw YabaiError.decoding(error)
        }
    }

    public func focus(space: Int, windowId: String) async throws {
        // run space focus then window focus
        // _ = try run(arguments: ["-m", "space", "--focus", "\(space)"])
        _ = try run(arguments: ["-m", "window", "--focus", windowId])
    }
}
