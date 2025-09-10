//
//  ContentView.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import SwiftUI
import Cocoa
import Combine
import ScreenCaptureKit
import AVFoundation

// MARK: - Models

struct Window: Identifiable, Decodable {
    let id: Int
    let app: String
    let title: String
    let space: Int
    let pid: pid_t

    var icon: NSImage? // not Decodable

    enum CodingKeys: String, CodingKey {
        case id, app, title, space, pid
        // do NOT include icon
    }

    init(id: Int, app: String, title: String, space: Int, pid: pid_t, icon: NSImage? = nil) {
        self.id = id
        self.app = app
        self.title = title
        self.space = space
        self.pid = pid
        self.icon = icon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        app = try container.decode(String.self, forKey: .app)
        title = try container.decode(String.self, forKey: .title)
        space = try container.decode(Int.self, forKey: .space)
        pid = try container.decode(Int32.self, forKey: .pid)
        icon = nil
    }
}

struct LaunchableApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String?
    let icon: NSImage?
}

struct CachedSnapshot {
    let image: NSImage
    let createdAt: Date
}

extension Window {
    var runningApp: NSRunningApplication? {
        guard pid > 0 else { return nil }
        return NSRunningApplication(processIdentifier: pid)
    }

    var appIcon: NSImage? {
        // Use running app icon if available, otherwise fallback to stored icon
        runningApp?.icon ?? icon
    }
}

// MARK: - Main View

struct WindowSwitcherView: View {
    @State private var filterText: String = ""
    @State private var windows: [Window] = []
    @State private var cachedWindows: [Window] = []
    @State private var selectedIndex: Int = 0
    @State private var timer: AnyCancellable?
    @State private var footerCommands: String? = nil
    @State private var previewImage: NSImage? = nil
    
    @State private var snapshotCache: [Int: CachedSnapshot] = [:] // Cache snapshots by window.id
    @State private var hasScreenCaptureAccess: Bool? = nil
    private let snapshotValidity: TimeInterval = 60
    
    @State private var cachedLaunchableApps: [LaunchableApp] = []
    
    @AppStorage("PreviewEnabled") private var isPreviewEnabled: Bool = true
    
    @FocusState private var isFocused
    
    var onClose: (([Window]) -> Void)?
    
    init(initialWindows: [Window] = [], onClose: (([Window]) -> Void)? = nil) {
        _windows = State(initialValue: initialWindows)
        self.onClose = onClose
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    header
                    windowList
                }
                .frame(width: isPreviewEnabled ? 400 : 900)
                
                if isPreviewEnabled {
                    Divider()
                    previewPanel
                        .frame(width: 500)
                }
            }
            .background(VisualEffectBlur(darkeningOpacity: 0.25))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .foregroundStyle(.primary)
            .frame(width: 900, height: 400)
            
            footer
                .frame(maxWidth: .infinity) // spans the whole width
        }
        .onAppear(perform: onAppear)
        .onExitCommand(perform: handleExitCommand)
        .onChange(of: filterText) { _, newValue in
            selectedIndex = 0
            clampSelectedIndex()
            
            if let window = displayedWindows[safe: selectedIndex] {
                Task { previewImage = await snapshot(of: window) }
            } else {
                previewImage = nil
            }
        }
    }
}

// MARK: - Subviews
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension WindowSwitcherView {
    var header: some View {
        VStack(spacing: 0) {
            KeyHandlingTextField(
                text: $filterText,
                isFocused: _isFocused,
                onEnter: handleEnter,
                onEscape: handleEscape,
                onTab: moveSelectionForward,
                onShiftTab: moveSelectionBackward
            )
            .frame(height: 30)
            .font(.title)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .padding(.bottom)
            
            Divider()
                .background(Color(white: 0.5).opacity(0.5))
                .frame(height: 0.08)
        }
        .padding()
    }
    
    var windowList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(displayedWindows.indices, id: \.self) { index in
                        let window = displayedWindows[index]
                        Button(action: { focusWindow(window) }) {
                            HStack(spacing: 8) {
                                // App Icon
                                if let icon = window.appIcon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 30, height: 30)
                                        .cornerRadius(4)
                                }
                                
                                // Title + App Name
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(window.title.isEmpty ? "(Untitled)" : window.title)
                                        .font(.headline)
                                    Text(window.app)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(index == selectedIndex ? Color.white.opacity(0.15) : .clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }

                Task {
                    if let window = displayedWindows[safe: newIndex] {
                        previewImage = await snapshot(of: window)
                    } else {
                        previewImage = nil
                    }
                }
            }
        }
    }
    
    var previewPanel: some View {
        ZStack {
            // Background blur covering the entire panel
            VisualEffectBlur(darkeningOpacity: 0.4)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            // Content
            VStack(alignment: .leading, spacing: 0) {
                if let img = previewImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("No preview")
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if hasScreenCaptureAccess == false {
                        Text("⚠️ Enable Screen Recording in System Settings → Privacy & Security")
                            .foregroundColor(.secondary)
                            .italic()
                            .padding()
                    }
                }
                
                // Debug info
                if let window = displayedWindows[safe: selectedIndex] {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Title: \(window.title.isEmpty ? "(Untitled)" : window.title)")
                        Text("App: \(window.app)")
                        Text("Space: \(window.space)")
                        Text("PID: \(window.pid)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding([.vertical, .trailing], 4)
                }
            }
            .padding()
        }
    }
    
    var footer: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color(white: 0.5).opacity(0.5))
                .frame(height: 0.08)
            
            HStack {
                // Left image/button
                Button(action: rickRoll) {
                    Image(systemName: "rectangle.3.offgrid")
                        .resizable()
                        .frame(width: 12, height: 12)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                // Middle: optional commands
                if let commands = footerCommands {
                    Text(commands)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                Spacer()
                
                // Right text
                Text("WindowSwitcher9000")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(VisualEffectBlur(darkeningOpacity: 0.4))
    }
}

// MARK: - Window Snapshots
// MARK: - One-shot delegate for snapshots

class SnapshotDelegate: NSObject, SCStreamOutput {
    var continuation: CheckedContinuation<CMSampleBuffer?, Never>?
    var didStop = false

    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        guard outputType == .screen, CMSampleBufferIsValid(sampleBuffer) else { return }
        continuation?.resume(returning: sampleBuffer)
        continuation = nil

        if !didStop {
            didStop = true
            Task { try? await stream.stopCapture() }
        }
    }
}
private extension WindowSwitcherView {
    func snapshot(of window: Window) async -> NSImage? {
        // If we already know access is denied, bail immediately
        if hasScreenCaptureAccess == false {
            return nil
        }

        // Use cached snapshot if still valid
        if let cached = snapshotCache[window.id],
           Date().timeIntervalSince(cached.createdAt) < snapshotValidity {
            return cached.image
        }

        do {
            let content = try await SCShareableContent.current
            hasScreenCaptureAccess = true

            guard let scWindow = content.windows.first(where: {
                $0.owningApplication?.processID == window.pid &&
                $0.isOnScreen &&
                (window.title.isEmpty || ($0.title ?? "").localizedCaseInsensitiveContains(window.title))
            }) else {
                return snapshotCache[window.id]?.image
            }

            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            config.width = Int(scWindow.frame.width)
            config.height = Int(scWindow.frame.height)

            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            let delegate = SnapshotDelegate()
            try stream.addStreamOutput(delegate, type: .screen, sampleHandlerQueue: .main)

            guard let frame = await withCheckedContinuation({ continuation in
                delegate.continuation = continuation
                Task {
                    do { try await stream.startCapture() }
                    catch {
                        continuation.resume(returning: nil)
                    }
                }
            }) else {
                return snapshotCache[window.id]?.image
            }

            guard let ciImage = ciImage(from: frame) else {
                return snapshotCache[window.id]?.image
            }

            let rep = NSCIImageRep(ciImage: ciImage)
            let nsImage = NSImage(size: rep.size)
            nsImage.addRepresentation(rep)

            snapshotCache[window.id] = CachedSnapshot(image: nsImage, createdAt: Date())
            
            // Update preview immediately on main thread
            DispatchQueue.main.async {
                if selectedIndex < windows.count, windows[selectedIndex].id == window.id {
                    previewImage = nsImage
                }
            }
            
            return nsImage

        } catch {
            // Mark as denied so we don't retry every refresh
            hasScreenCaptureAccess = false
            print("❌ ScreenCaptureKit error: \(error)")
            return snapshotCache[window.id]?.image
        }
    }

    private func ciImage(from sampleBuffer: CMSampleBuffer) -> CIImage? {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return nil }
        return CIImage(cvPixelBuffer: pixelBuffer)
    }
}


// MARK: - Computed Properties

private extension WindowSwitcherView {
    var filteredWindows: [Window] {
        guard !filterText.isEmpty else { return windows }
        
        let threshold = max(3, filterText.count / 2)
        
        return windows
            .map { ($0, fuzzyScore(text: $0.title + " " + $0.app, pattern: filterText)) }
            .filter { $0.1 >= threshold }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
    
    var displayedWindows: [Window] {
        // Only running windows with non-empty title
        let validWindows = windows.filter { !$0.title.isEmpty }

        var scoredWindows: [(Window, Int)] = validWindows.map {
            ($0, fuzzyScore(text: $0.title + " " + $0.app, pattern: filterText))
        }

        // Only include launchable apps if filter text is not empty
        if !filterText.isEmpty {
            let launchableWindows: [(Window, Int)] = cachedLaunchableApps.compactMap { app in
                let title = "Open \(app.name)"
                guard title.lowercased().contains(filterText.lowercased()) else { return nil }
                let score = fuzzyScore(text: title, pattern: filterText)
                let window = Window(
                    id: Int.random(in: Int.min..<0), // temporary negative ID, will never be focused by yabai
                    app: app.name,
                    title: title,
                    space: 0,
                    pid: 0,
                    icon: app.icon
                )
                return (window, score)
            }
            scoredWindows.append(contentsOf: launchableWindows)
        }

        return scoredWindows.sorted { $0.1 > $1.1 }.map { $0.0 }
    }
}

// MARK: - Lifecycle
private extension WindowSwitcherView {
    func onAppear() {
        isFocused = true
        observePanelFocus()
        refreshWindows()
        loadLaunchableApps() // cache apps once
    }
    
    func handleExitCommand() {
        if !filterText.isEmpty {
            filterText = ""
        } else {
            onClose?(windows)
        }
    }
    
    private func observePanelFocus() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { _ in
            startAutoRefresh()
            refreshWindows()
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { _ in
            stopAutoRefresh()
        }
    }

    private func startAutoRefresh() {
        timer?.cancel()
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                refreshWindows()
            }
    }
    
    private func stopAutoRefresh() {
        timer?.cancel()
        timer = nil
    }
}

// MARK: - Selection Handling

private extension WindowSwitcherView {
    func moveSelectionForward() {
        guard !displayedWindows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % displayedWindows.count
    }

    func moveSelectionBackward() {
        guard !displayedWindows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + displayedWindows.count) % displayedWindows.count
    }

    func handleEnter() {
        if let command = extractCommand(from: filterText) {
            handleCommand(command)
            return
        }
        selectWindow()
        filterText = ""
    }

    func handleEscape() {
        if !filterText.isEmpty {
            filterText = ""
        } else {
            onClose?(windows)
        }
        footerCommands = nil
    }
    
    func selectWindow() {
        guard displayedWindows.indices.contains(selectedIndex) else { return }
        let window = displayedWindows[selectedIndex]

        if window.pid == 0 {
            // Launchable app
            if let app = cachedLaunchableApps.first(where: { $0.name == window.app }) {
                if let bundleID = app.bundleID,
                   let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    
                    // ✅ Modern API
                    let config = NSWorkspace.OpenConfiguration()
                    NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, error in
                        if let error = error {
                            print("Failed to open \(app?.localizedName ?? window.app): \(error)")
                        }
                    }
                } else {
                    // Fallback: try opening by name via shell
                    let task = Process()
                    task.launchPath = "/usr/bin/open"
                    task.arguments = ["-a", window.app]
                    task.launch()
                }
            }
        } else {
            // Running window
            focusWindow(window)
        }

        onClose?(windows)
    }
}

// MARK: - Window Management

private extension WindowSwitcherView {
    func loadWindows() -> [Window] {
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = [
            "-c",
            "/opt/homebrew/bin/yabai -m query --windows | jq -c '.[] | {id: .id, app: .app, title: .title, space: .space, pid: .pid}'"
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        guard
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        else {
            return []
        }
        
        let decoder = JSONDecoder()
        return output
            .split(separator: "\n")
            .compactMap { line in
                line.data(using: .utf8).flatMap { try? decoder.decode(Window.self, from: $0) }
            }
    }

    func refreshWindows() {
        DispatchQueue.global(qos: .userInitiated).async {
            let newWindows = loadWindows().sorted {
                $0.app == $1.app ? $0.title < $1.title : $0.app < $1.app
            }
            
            DispatchQueue.main.async {
                self.cachedWindows = newWindows.isEmpty ? self.cachedWindows : newWindows
                self.windows = newWindows
                self.clampSelectedIndex()
            }
        }
        if let window = windows[safe: selectedIndex], snapshotCache[window.id] == nil {
            Task { _ = await snapshot(of: window) }
        }
    }

    func focusWindow(_ window: Window) {
        let task = Process()
        task.launchPath = "/bin/zsh"
        
        task.arguments = [
            "-c",
            "/opt/homebrew/bin/yabai -m space --focus \(window.space); /opt/homebrew/bin/yabai -m window --focus \(window.id)"
        ]
        
        task.launch()
    }

    func clampSelectedIndex() {
        let count = displayedWindows.count
        if selectedIndex >= count {
            selectedIndex = max(0, count - 1)
        }
    }
}

// MARK: - Utilities

private extension WindowSwitcherView {
    func fuzzyScore(text: String, pattern: String) -> Int {
        let text = text.lowercased()
        let pattern = pattern.lowercased()
        
        // Exact substring match gets highest score
        if text.contains(pattern) { return 1000 }
        
        var score = 0
        var lastIndex = text.startIndex
        var consecutive = 0
        
        for char in pattern {
            if let idx = text[lastIndex...].firstIndex(of: char) {
                let distance = text.distance(from: lastIndex, to: idx)
                
                // Reward consecutive matches
                if distance == 0 { consecutive += 1 } else { consecutive = 1 }
                
                // Score: consecutive characters + inverse of gap
                score += consecutive * 10 - distance
                
                lastIndex = text.index(after: idx)
            } else {
                break
            }
        }
        
        // Boost prefix matches of words
        let words = text.split(separator: " ")
        for word in words {
            if word.hasPrefix(pattern) {
                score += 50
            }
        }
        
        return max(score, 0)
    }

    func extractCommand(from text: String) -> String? {
        let regex = try! NSRegularExpression(pattern: #"^/([^/]+)/$"#)
        let range = NSRange(location: 0, length: text.utf16.count)
        
        guard
            let match = regex.firstMatch(in: text, range: range),
            let commandRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[commandRange]).uppercased()
    }
    
    func handleCommand(_ command: String) {
        print("WindowSwitcher : command '\(command)'")
        switch command {
        case "SHOW_ICON":
            MenuBarHandler.shared.showBarIcon()
        case "HIDE_ICON":
            MenuBarHandler.shared.hideBarIcon()
        case "TOGGLE_DOCK":
            MenuBarHandler.shared.toggleDockIcon()
        case "QUIT":
            MenuBarHandler.shared.quit()
        case "HELP":
            footerCommands = "/commands/: show_icon, hide_icon, toggle_dock, quit, help"
        default:
            print("Unknown command: \(command)")
        }
    }
    
    func rickRoll() {
        if let url = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func installedLaunchableApps() -> [LaunchableApp] {
        var installed: [LaunchableApp] = []

        let appDirs = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask) +
                      FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask)

        for dir in appDirs {
            guard let appURLs = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for url in appURLs where url.pathExtension == "app" {
                let bundle = Bundle(url: url)
                let name = bundle?.infoDictionary?["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
                let bundleID = bundle?.bundleIdentifier
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                installed.append(LaunchableApp(name: name, bundleID: bundleID, icon: icon))
            }
        }

        return installed
    }
    
    private func launchableWindows(from apps: [LaunchableApp]) -> [Window] {
        apps.enumerated().map { idx, app in
            Window(
                id: -(idx + 1),           // negative id for launchables
                app: app.name,             // original app name for launching
                title: "Open \(app.name)", // title shown in the list
                space: 0,
                pid: 0
            )
        }
    }
    
    private func loadLaunchableApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = installedLaunchableApps()
            DispatchQueue.main.async {
                self.cachedLaunchableApps = apps
            }
        }
    }
}

// MARK: - Visual Effect Blur

private struct VisualEffectBlur: NSViewRepresentable {
    var darkeningOpacity: CGFloat = 0.4

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .sidebar
        view.state = .active
        
        let darkOverlay = NSView()
        darkOverlay.wantsLayer = true
        darkOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(darkeningOpacity).cgColor
        darkOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(darkOverlay)
        
        NSLayoutConstraint.activate([
            darkOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            darkOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            darkOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            darkOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.subviews.first?.layer?.backgroundColor =
            NSColor.black.withAlphaComponent(darkeningOpacity).cgColor
    }
}

// MARK: - Preview

#Preview {
    WindowSwitcherView()
}
