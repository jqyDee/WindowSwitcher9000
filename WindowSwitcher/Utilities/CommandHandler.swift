//
//  Command.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 15.09.25.
//


//
//  CommandHandler.swift
//  WindowSwitcher
//
//  Created by Copilot on 2025-09-15.
//

import Foundation

public enum Command: String {
    case showIcon = "SHOW_ICON"
    case hideIcon = "HIDE_ICON"
    case toggleDock = "TOGGLE_DOCK"
    case quit = "QUIT"
    case help = "HELP"
    case debug = "DEBUG"
    case unknown

    public static func from(_ raw: String) -> Command {
        Command(rawValue: raw.uppercased()) ?? .unknown
    }
}

public struct CommandHandler {
    /// Extracts a command from a text in the format `/COMMAND/`.
    /// - Parameter text: The input string, e.g. `/HELP/`.
    /// - Returns: The Command if matched, or `.unknown` if not.
    public static func extractCommand(from text: String) -> Command? {
        let regex = try! NSRegularExpression(pattern: #"^/([^/]+)/$"#)
        let r = NSRange(location: 0, length: text.utf16.count)
        guard let m = regex.firstMatch(in: text, range: r),
              let range = Range(m.range(at: 1), in: text) else { return nil }
        return Command.from(String(text[range]))
    }

    /// Handles a command and returns a UI feedback string if appropriate.
    /// Your ViewModel may call this and bind the result to the footer or a status.
    public static func handle(_ command: Command) -> String? {
        switch command {
        case .showIcon:
            MenuBarHandler.shared.showBarIcon()
            return "Menu Bar Icon shown"
        case .hideIcon:
            MenuBarHandler.shared.hideBarIcon()
            return "Menu Bar Icon hidden"
        case .toggleDock:
            MenuBarHandler.shared.toggleDockIconProgrammatically()
            return "Toggled Dock Icon \(MenuBarHandler.shared.isDockHidden == false ? "on" : "off")"
        case .quit:
            MenuBarHandler.shared.quit()
            return "Quitting"
        case .debug:
            MenuBarHandler.shared.toggleDebugMode()
            return "toggled Debug"
        case .help:
            return "/commands/: show_icon, hide_icon, toggle_dock, quit, help, debug"
        case .unknown:
            return nil
        }
    }
}
