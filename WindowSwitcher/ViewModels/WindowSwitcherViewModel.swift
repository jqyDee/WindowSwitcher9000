//
//  WindowSwitcherViewModel.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//


import Foundation
import AppKit
import Combine

@MainActor
public final class WindowSwitcherViewModel: ObservableObject {
    // Inputs
    @Published public var filterText: String = ""
    @Published public var isPreviewEnabled: Bool = true

    // Outputs (bind to View)
    @Published public var windows: [Window] = []
    @Published public var displayedWindows: [Window] = []
    @Published public var selectedIndex: Int = 0 {
        didSet {
            if oldValue != selectedIndex {
                requestSnapshotForSelected()
            }
        }
    }
    @Published public var previewImage: NSImage? = nil
    @Published public var hasScreenCaptureAccess: Bool? = nil
    @Published public var footerCommands: String? = nil
    @Published public var cachedLaunchableApps: [LaunchableApp] = []

    // dependencies
    private let yabai: YabaiServiceProtocol
    private let snapshotService: SnapshotServiceProtocol

    // internals
    private var refreshTask: Task<Void, Never>?
    private var snapshotTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    public init(yabai: YabaiServiceProtocol = YabaiClient(),
                snapshotService: SnapshotServiceProtocol = SnapshotService()) {
        self.yabai = yabai
        self.snapshotService = snapshotService

        // react to filter changes
        $filterText
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    self.recomputeDisplay()
                    self.selectedIndex = 0
                }
            }
            .store(in: &cancellables)
    }
    
    func initializeOnOpen() async {
        await refreshWindows()
        clampSelectedIndex()
        startAutoRefresh()
        requestSnapshotForSelected()
    }

    public func loadLaunchableApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            var installed: [LaunchableApp] = []
            
            // Check user, local, and system Applications folders
            let appDirs = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask) +
            FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask) +
            [URL(fileURLWithPath: "/System/Applications")]
            
            for dir in appDirs {
                guard let appURLs = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
                for url in appURLs where url.pathExtension == "app" {
                    let bundle = Bundle(url: url)
                    let name = bundle?.infoDictionary?["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
                    let bundleID = bundle?.bundleIdentifier
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    icon.size = NSSize(width: 64, height: 64) // optional: scale nicely
                    installed.append(LaunchableApp(name: name, bundleID: bundleID, icon: icon))
                }
            }
            
            var apps = installed
            
            // Force-include Finder
            if !apps.contains(where: { $0.name == "Finder" }) {
                let finderIcon = NSWorkspace.shared.icon(forFile: "/System/Applications/Finder.app")
                finderIcon.size = NSSize(width: 64, height: 64)
                apps.append(LaunchableApp(name: "Finder", bundleID: "com.apple.finder", icon: finderIcon))
            }
            
            DispatchQueue.main.async {
                self.cachedLaunchableApps = apps
            }
        }
    }

    public func refreshWindows() async {
        do {
            let newWindows = try await yabai.queryWindows()
            // Map over newWindows, carrying over any cached screenshot
            let carried = newWindows.map { newWin in
                if let old = windows.first(where: { $0.id == newWin.id && $0.pid == newWin.pid && $0.title == newWin.title }),
                   let cached = old.cachedScreenshot
                {
                    var win = newWin
                    win.cachedScreenshot = cached
                    return win
                } else {
                    return newWin
                }
            }
            windows = carried.sorted { $0.app == $1.app ? $0.title < $1.title : $0.app < $1.app }
            recomputeDisplay()
            clampSelectedIndex()
        } catch {
            print("refresh windows error: \(error)")
        }
    }
    public func startAutoRefresh(interval: TimeInterval = 1.0) {
        refreshTask?.cancel()
        refreshTask = Task.detached { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refreshWindows()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
    
    private func recomputeDisplay() {
        // simple fuzzy scoring: reuse your existing fuzzyScore implementation
        let filter = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        var scored: [(Window, Int)] = windows.map { (w) in
            // Look up the cached screenshot for this window (if any)
            var windowWithCache = w
            if let cached = self.windows.first(where: { $0.id == w.id && $0.pid == w.pid && $0.title == w.title })?.cachedScreenshot {
                windowWithCache.cachedScreenshot = cached
            }
            return (windowWithCache, fuzzyScore(text: windowWithCache.title + " " + windowWithCache.app, pattern: filter))
        }
        
        // add launchable apps when filtering
        if !filter.isEmpty {
            let launchables = cachedLaunchableApps.compactMap { app -> (Window, Int)? in
                let title = "Open \(app.name)"
                guard title.lowercased().contains(filter.lowercased()) else { return nil }
                let isRunning = app.bundleID.flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0).first } != nil
                let win = Window(id: "launch:\(app.bundleID ?? app.name)",
                                 app: app.name,
                                 title: title,
                                 space: 0,
                                 pid: isRunning ? (NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID ?? "").first?.processIdentifier ?? 0) : 0,
                                 icon: app.icon)
                return (win, fuzzyScore(text: title, pattern: filter))
            }
            scored.append(contentsOf: launchables)
        }

        displayedWindows = scored.sorted { $0.1 > $1.1 }.map { $0.0 }
    }
    
    public func clampSelectedIndex() {
        if selectedIndex >= displayedWindows.count {
            selectedIndex = max(0, displayedWindows.count - 1)
        }
    }

    public func moveSelectionForward() {
        guard !displayedWindows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % displayedWindows.count
    }
    public func moveSelectionBackward() {
        guard !displayedWindows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + displayedWindows.count) % displayedWindows.count
    }

    public func requestSnapshotForSelected() {
        guard isPreviewEnabled else { previewImage = nil; return }
        guard displayedWindows.indices.contains(selectedIndex) else { previewImage = nil; return }

        let window = displayedWindows[selectedIndex]

        Task { @MainActor in
            do {
                let img = try await snapshotService.snapshot(window: window)
                previewImage = img
                // Find and update the window in the windows array
                if let idx = self.windows.firstIndex(where: { $0.id == window.id && $0.pid == window.pid && $0.title == window.title }) {
                    var updated = self.windows[idx]
                    updated.cachedScreenshot = Snapshot(image: img, createdAt: Date.now)
                    self.windows[idx] = updated
                    // Optionally, recompute displayedWindows if you want to immediately reflect the update
                    self.recomputeDisplay()
                }
                hasScreenCaptureAccess = true
            } catch SnapshotError.permissionDenied {
                hasScreenCaptureAccess = false
            } catch {
                print("snapshot error: \(error)")
                // Show cached image if available
                if let cached = window.cachedScreenshot {
                    previewImage = cached.image
                } else {
                    previewImage = nil
                }
            }
        }
    }
    
    public func focusWindow(_ window: Window) {
        Task {
            do {
                try await yabai.focus(space: window.space, windowId: window.id)
            } catch {
                // fallback: open app
                if window.pid == 0 {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: window.app) {
                        NSWorkspace.shared.open(url)
                    } else {
                        openAppViaShell(appName: window.app)
                    }
                } else {
                    openAppViaShell(appName: window.app)
                }
            }
        }
    }

    public func handleEnter() {
        if let cmd = extractCommand(from: filterText) {
            handleCommand(cmd)
            return
        }
        guard displayedWindows.indices.contains(selectedIndex) else { return }
        let window = displayedWindows[selectedIndex]
        if window.pid == 0 {
            // launchable
            if let app = cachedLaunchableApps.first(where: { $0.name == window.app }) {
                if let bundleID = app.bundleID,
                   let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    let config = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, err in
                        if let err { print("open app error:", err) }
                    }
                } else {
                    openAppViaShell(appName: window.app)
                }
            }
        } else {
            focusWindow(window)
        }
    }

    private func fuzzyScore(text: String, pattern: String) -> Int {
        guard !pattern.isEmpty else { return 1000 }
        let t = text.lowercased()
        let p = pattern.lowercased()
        if t.contains(p) { return 10000 }
        var score = 0
        var last = t.startIndex
        var consecutive = 0
        for c in p {
            if let idx = t[last...].firstIndex(of: c) {
                let distance = t.distance(from: last, to: idx)
                if distance == 0 { consecutive += 1 } else { consecutive = 1 }
                score += consecutive * 10 - distance
                last = t.index(after: idx)
            } else { break }
        }
        let words = t.split(separator: " ")
        for w in words where w.hasPrefix(p) { score += 50 }
        return max(score, 0)
    }

    private func extractCommand(from text: String) -> String? {
        let regex = try! NSRegularExpression(pattern: #"^/([^/]+)/$"#)
        let r = NSRange(location: 0, length: text.utf16.count)
        guard let m = regex.firstMatch(in: text, range: r),
              let range = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[range]).uppercased()
    }

    // TODO: not implemented
    private func handleCommand(_ command: String) {
        switch command {
        case "SHOW_ICON": break // wire up to menu bar manager
        case "HIDE_ICON": break
        case "TOGGLE_DOCK": break
        case "QUIT": break
        case "HELP":
            footerCommands = "/commands/: show_icon, hide_icon, toggle_dock, quit, help"
        default:
            footerCommands = nil
        }
    }
    
    private func openAppViaShell(appName: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appName]
        do {
            try process.run()
        } catch {
            print("Failed to open app \(appName): \(error)")
        }
    }
}
