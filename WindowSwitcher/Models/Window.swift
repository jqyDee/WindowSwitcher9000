//
//  Window.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//

import Cocoa


/// Domain model used across the app. Decodes yabai JSON where `id` may be an Int or String.
public struct Window: Identifiable, Codable, Hashable {
    public let id: String
    public let app: String
    public let title: String
    public let space: Int
    public let pid: pid_t

    // runtime-only
    public var icon: NSImage?

    enum CodingKeys: String, CodingKey {
        case id, app, title, space, pid
    }

    public init(id: String, app: String, title: String, space: Int, pid: pid_t, icon: NSImage? = nil) {
        self.id = id
        self.app = app
        self.title = title
        self.space = space
        self.pid = pid
        self.icon = icon
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // yabai sometimes returns numbers for id
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }

        app = try container.decode(String.self, forKey: .app)
        title = try container.decode(String.self, forKey: .title)
        space = try container.decode(Int.self, forKey: .space)
        pid = try container.decode(Int32.self, forKey: .pid)
        icon = nil
    }
}

extension Window {
    // convenience for running app
    public var runningApp: NSRunningApplication? {
        guard pid > 0 else { return nil }
        return NSRunningApplication(processIdentifier: pid)
    }

    public var appIcon: NSImage? {
        runningApp?.icon ?? icon
    }
}
