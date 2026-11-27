//
//  NativeClient.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//

import Cocoa
import ApplicationServices

// MARK: - Private API declarations (technique from alt-tab-macos)

private typealias CGSConnectionID = UInt32

private let CGS_CONNECTION = CGSMainConnectionID()

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("GetProcessForPID") @discardableResult
private func GetProcessForPID(_ pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

@_silgen_name("_SLPSSetFrontProcessWithOptions") @discardableResult
private func _SLPSSetFrontProcessWithOptions(_ psn: UnsafeMutablePointer<ProcessSerialNumber>, _ wid: CGWindowID, _ mode: UInt32) -> CGError

@_silgen_name("SLPSPostEventRecordTo") @discardableResult
private func SLPSPostEventRecordTo(_ psn: UnsafeMutablePointer<ProcessSerialNumber>, _ bytes: UnsafeMutablePointer<UInt8>) -> CGError

@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

@_silgen_name("CGSCopySpacesForWindows")
private func CGSCopySpacesForWindows(_ cid: CGSConnectionID, _ mask: Int, _ windowIDs: CFArray) -> CFArray

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray

private let SLPSUserGenerated: UInt32 = 0x200
private let CGSAllSpacesMask = 0x7

// MARK: - NativeClient

public actor NativeClient: WindowServiceProtocol {

    public init() {}

    public func queryWindows() async throws -> [Window] {
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] else {
            return []
        }

        let visibleSpaces = Self.visibleSpaceIDs()
        // Per app: its real windows and their titles, as reported through Accessibility (fetched lazily)
        var axWindowsByPID: [pid_t: [CGWindowID: String]] = [:]
        func axWindows(_ pid: pid_t) -> [CGWindowID: String] {
            if let cached = axWindowsByPID[pid] { return cached }
            let windows = Self.axWindowTitles(pid: pid)
            axWindowsByPID[pid] = windows
            return windows
        }

        return list.compactMap { info -> Window? in
            guard let layer = info[kCGWindowLayer] as? Int, layer == 0 else { return nil }
            guard let windowID = info[kCGWindowNumber] as? Int else { return nil }
            guard let pid = info[kCGWindowOwnerPID] as? pid_t, pid > 0 else { return nil }

            // Only apps with a Dock presence: drops menu-bar apps (e.g. Bitwarden) and system agents/prompts
            guard let runningApp = NSRunningApplication(processIdentifier: pid),
                  runningApp.activationPolicy == .regular else { return nil }

            // kCGWindowName is only filled in with Screen Recording permission; Accessibility provides
            // titles without it (for windows on the current spaces).
            var title = info[kCGWindowName] as? String ?? ""
            if title.isEmpty {
                title = axWindows(pid)[CGWindowID(windowID)] ?? ""
            }
            guard !title.isEmpty else { return nil }

            let isOnScreen = info[kCGWindowIsOnscreen] as? Bool ?? false
            if !isOnScreen {
                let cgWindowID = CGWindowID(windowID)
                let spaces = CGSCopySpacesForWindows(CGS_CONNECTION, CGSAllSpacesMask, [cgWindowID] as CFArray) as? [Int] ?? []
                // On no space at all: a closed window the app keeps in memory
                guard !spaces.isEmpty else { return nil }
                // Off screen on a space that is showing: real only if the app still lists it (e.g. minimized).
                // Windows on other spaces can't be checked this way (AX doesn't see them), so they are kept.
                if spaces.contains(where: visibleSpaces.contains) {
                    guard axWindows(pid)[cgWindowID] != nil else { return nil }
                }
            }

            let appName = info[kCGWindowOwnerName] as? String ?? ""

            return Window(
                id: String(windowID),
                app: appName,
                title: title,
                space: 0,
                pid: pid,
                icon: runningApp.icon,
                bundleID: runningApp.bundleIdentifier
            )
        }
    }

    /// The space currently shown on each display.
    private static func visibleSpaceIDs() -> Set<Int> {
        let displays = CGSCopyManagedDisplaySpaces(CGS_CONNECTION) as? [[String: Any]] ?? []
        return Set(displays.compactMap { ($0["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int })
    }

    /// The windows an app reports through Accessibility (its real windows, minimized ones included),
    /// keyed by window ID, with their titles ("" if the app reports none).
    private static func axWindowTitles(pid: pid_t) -> [CGWindowID: String] {
        let axApp = AXUIElementCreateApplication(pid)
        // Don't let an unresponsive app stall the window query (AX default timeout is ~6s)
        AXUIElementSetMessagingTimeout(axApp, 0.25)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let axWindows = windowsRef as? [AXUIElement] else { return [:] }
        var titles: [CGWindowID: String] = [:]
        for axWindow in axWindows {
            var wid: CGWindowID = 0
            guard _AXUIElementGetWindow(axWindow, &wid) == .success, wid != 0 else { continue }
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
            titles[wid] = titleRef as? String ?? ""
        }
        return titles
    }

    public func focus(space: Int, windowId: String) async throws {
        guard let cgWindowID = UInt32(windowId) else { return }
        guard let pid = Self.pid(forWindow: cgWindowID) else { return }
        Self.focusWindow(pid: pid, cgWindowID: cgWindowID)
    }

    nonisolated public func focusFast(space: Int, windowId: String) {
        guard let cgWindowID = UInt32(windowId) else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let pid = Self.pid(forWindow: cgWindowID) else { return }
            Self.focusWindow(pid: pid, cgWindowID: cgWindowID)
        }
    }

    private static func pid(forWindow windowID: CGWindowID) -> pid_t? {
        guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[CFString: Any]] else {
            return nil
        }
        for info in list {
            guard let wid = info[kCGWindowNumber] as? Int, CGWindowID(wid) == windowID else { continue }
            return info[kCGWindowOwnerPID] as? pid_t
        }
        return nil
    }

    private static func focusWindow(pid: pid_t, cgWindowID: CGWindowID) {
        var psn = ProcessSerialNumber()
        GetProcessForPID(pid, &psn)

        // Brings window to front — handles cross-space switching internally
        _SLPSSetFrontProcessWithOptions(&psn, cgWindowID, SLPSUserGenerated)

        // Send raw WindowServer event to make this window key
        makeKeyWindow(psn: &psn, cgWindowID: cgWindowID)

        // Optional AX focus (no-op if app doesn't expose AX windows)
        let axApp = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let axWindows = windowsRef as? [AXUIElement] {
            for axWindow in axWindows {
                var wid: CGWindowID = 0
                guard _AXUIElementGetWindow(axWindow, &wid) == .success, wid == cgWindowID else { continue }
                AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
                break
            }
        }
    }

    // Ported from https://github.com/lwouis/alt-tab-macos
    // Sends raw WindowServer bytes to make a specific window key.
    private static func makeKeyWindow(psn: inout ProcessSerialNumber, cgWindowID: CGWindowID) {
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        var wid = cgWindowID
        memcpy(&bytes[0x3c], &wid, MemoryLayout<UInt32>.size)
        memset(&bytes[0x20], 0xff, 0x10)
        bytes[0x08] = 0x01
        SLPSPostEventRecordTo(&psn, &bytes)
        bytes[0x08] = 0x02
        SLPSPostEventRecordTo(&psn, &bytes)
    }
}
