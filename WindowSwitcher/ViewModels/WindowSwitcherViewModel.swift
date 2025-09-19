//
//  WindowSwitcherViewModel.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//

import Foundation
import AppKit
import Combine
import SwiftUI

@MainActor
public final class WindowSwitcherViewModel: ObservableObject {
    // MARK: - Published Properties (Inputs & Outputs)
    @AppStorage("PreviewEnabled") public var isPreviewEnabled: Bool = true
    @Published public var filterText: String = ""
    @Published public var windows: [Window] = []
    @Published public var displayedWindows: [Window] = []
    @Published public var selectedIndex: Int = 0 {
        didSet {
            requestSnapshotForSelected()
        }
    }
    @Published public var previewImage: NSImage? = nil
    @Published public var hasScreenCaptureAccess: Bool? = nil
    @Published public var footerCommands: String? = nil
    @Published public var cachedLaunchableApps: [LaunchableApp] = []
    
    // MARK: - Dependencies
    private let yabai: YabaiServiceProtocol
    private let snapshotService: SnapshotServiceProtocol

    // MARK: - Internals
    private var autoRefreshService: AutoRefreshService?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    public init(
        yabai: YabaiServiceProtocol = YabaiClient(),
        snapshotService: SnapshotServiceProtocol = SnapshotService()
    ) {
        self.yabai = yabai
        self.snapshotService = snapshotService
        setupBindings()
    }

    private func setupBindings() {
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

    // MARK: - Public API

    public func initializeOnOpen() async {
        await refreshWindows()
        clampSelectedIndex()
        startAutoRefresh()
        requestSnapshotForSelected()
    }

    public func loadLaunchableApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let appDirs = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask) +
                          FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask) +
                          [URL(fileURLWithPath: "/System/Applications")] +
                          [URL(fileURLWithPath: "/System/Applications/Utilities")]
            
            var installed: [LaunchableApp] = []

            for dir in appDirs {
                guard let appURLs = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
                for url in appURLs where url.pathExtension == "app" {
                    let bundle = Bundle(url: url)
                    let name = bundle?.infoDictionary?["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
                    let bundleID = bundle?.bundleIdentifier
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    icon.size = NSSize(width: 64, height: 64)
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
            let carried = carryOverCache(from: newWindows)
            // filter out empty windows and windows which title is 'Window'. I don't really understand
            // where they are coming from but anyway.
            let filtered = carried.filter { !$0.title.isEmpty }
            windows = filtered.sorted(by: Self.windowSort)
            recomputeDisplay()
            clampSelectedIndex()
        } catch {
            print("refresh windows error: \(error)")
        }
    }

    public func startAutoRefresh(interval: TimeInterval = 1.0) {
        autoRefreshService?.stop()
        autoRefreshService = AutoRefreshService(interval: interval) { [weak self] in
            guard let self = self else { return }
            await self.refreshWindows()
        }
        autoRefreshService?.start()
    }

    public func stopAutoRefresh() {
        autoRefreshService?.stop()
    }

    public func moveSelectionForward() {
        guard !displayedWindows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % displayedWindows.count
    }

    public func moveSelectionBackward() {
        guard !displayedWindows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + displayedWindows.count) % displayedWindows.count
    }

    public func clampSelectedIndex() {
        if selectedIndex >= displayedWindows.count {
            selectedIndex = max(0, displayedWindows.count - 1)
        }
    }

    public func requestSnapshotForSelected() {
        guard isPreviewEnabled else { previewImage = nil; return }
        guard displayedWindows.indices.contains(selectedIndex) else { previewImage = nil; return }

        // no snapshots for not even possibly visible windows
        let window = displayedWindows[selectedIndex]
        if window.space == 0 {
            previewImage = nil
            return
        }
        
        let cacheValidityInSeconds = 120.0
        if let cachedSnapshot = window.cachedSnapshot, abs(cachedSnapshot.createdAt.timeIntervalSinceNow) < cacheValidityInSeconds {
            previewImage = cachedSnapshot.image
            return
        }

        Task { @MainActor in
            do {
                let img = try await snapshotService.snapshot(window: window)
                previewImage = img
                updateCachedSnapshot(for: window, image: img)
                hasScreenCaptureAccess = true
            } catch SnapshotError.permissionDenied {
                hasScreenCaptureAccess = false
            } catch {
                print("snapshot error: \(error)")
                if let cached = window.cachedSnapshot {
                    previewImage = cached.image
                } else {
                    previewImage = nil
                }
            }
        }
    }

    // kind of deprecated
    public func focusWindow(_ window: Window) {
        Task {
            do {
                try await yabai.focus(space: window.space, windowId: window.id)
            } catch {
                AppLauncher.openAppByName(window.app)
            }
        }
    }

    public func handleEnter() {
        if let cmd = CommandHandler.extractCommand(from: filterText) {
            self.footerCommands = CommandHandler.handle(cmd)
            return
        }
        
        filterText = ""
        FloatingPanelHandler.shared.closePanel()

        guard displayedWindows.indices.contains(selectedIndex) else { return }
        let window = displayedWindows[selectedIndex]
        if window.pid == 0 || window.id.starts(with: "launch:"){
            AppLauncher.openAppByName(window.app)
        } else {
            yabai.focusFast(space: window.space, windowId: "\(window.id)")
        }
    }
    
    public func handleEscape() {
        if !filterText.isEmpty {
            filterText = ""
        } else {
            FloatingPanelHandler.shared.closePanel()
        }
    }

    // MARK: - Private Helpers

    private static func windowSort(lhs: Window, rhs: Window) -> Bool {
        lhs.app == rhs.app ? lhs.title < rhs.title : lhs.app < rhs.app
    }

    private func carryOverCache(from newWindows: [Window]) -> [Window] {
        newWindows.map { newWin in
            if let old = windows.first(where: {
                $0.id == newWin.id &&
                $0.pid == newWin.pid &&
                $0.title == newWin.title
            }) {
                var win = newWin
                if let snap = old.cachedSnapshot {
                    win.cachedSnapshot = snap
                }
                if let icn = old.icon {
                    win.icon = icn
                }
                return win
            } else {
                return newWin
            }
        }
    }

    private func updateCachedSnapshot(for window: Window, image: NSImage) {
        if let idx = self.windows.firstIndex(where: { $0.id == window.id && $0.pid == window.pid && $0.title == window.title }) {
            var updated = self.windows[idx]
            updated.cachedSnapshot = Snapshot(image: image, createdAt: Date.now)
            self.windows[idx] = updated
            // Optionally, recompute displayedWindows if you want to immediately reflect the update
            self.recomputeDisplay()
        }
    }

    private func launchApp(for window: Window) {
        AppLauncher.openAppByName(window.app)
    }

    private func recomputeDisplay() {
        let filter = filterText.trimmed

        // 1. Real windows
        var scored: [(Window, Double)] = windows.map { w in
            var windowWithCache = w
            if let cached = self.windows.first(where: { $0.id == w.id && $0.pid == w.pid && $0.title == w.title })?.cachedSnapshot {
                windowWithCache.cachedSnapshot = cached
            }

            let text = windowWithCache.title + " " + windowWithCache.app
            var score = FuzzySearch.score(text: text, pattern: filter) ?? -Double.infinity

            // Bias for real windows
            score += 0.5

            return (windowWithCache, score)
        }

        // 2. Launchables
        if !filter.isEmpty {
            let launchables = cachedLaunchableApps.compactMap { app -> (Window, Double)? in
                let title = "Open \(app.name)"
                guard let scoreRaw = FuzzySearch.score(text: title, pattern: filter) else { return nil }

                // Slight penalty for launchables
                let score = scoreRaw - 0.5

                let isRunning = app.bundleID.flatMap {
                    NSRunningApplication.runningApplications(withBundleIdentifier: $0).first
                } != nil

                let win = Window(
                    id: "launch:\(app.bundleID ?? app.name)",
                    app: app.name,
                    title: title,
                    space: 0,
                    pid: isRunning
                        ? (NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID ?? "").first?.processIdentifier ?? 0)
                        : 0,
                    icon: app.icon
                )
                return (win, score)
            }
            scored.append(contentsOf: launchables)
        }

        // 3. Sort & apply
        displayedWindows = scored
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
}
