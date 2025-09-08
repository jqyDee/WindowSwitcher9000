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
}

struct CachedSnapshot {
    let image: NSImage
    let createdAt: Date
}

extension Window {
    var runningApp: NSRunningApplication? {
        NSRunningApplication(processIdentifier: pid)
    }

    var appIcon: NSImage? {
        runningApp?.icon
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
    private let snapshotValidity: TimeInterval = 60
    
    @FocusState private var isFocused

    var onClose: (([Window]) -> Void)?
    
    init(initialWindows: [Window] = [], onClose: (([Window]) -> Void)? = nil) {
        _windows = State(initialValue: initialWindows)
        self.onClose = onClose
    }
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                windowList
                footer
            }
            .frame(width: 400)
            
            Divider()
            
            previewPanel
                .frame(width: 500)
        }
        .background(VisualEffectBlur(darkeningOpacity: 0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .foregroundStyle(.primary)
        .frame(width: 900, height: 400)
        .onAppear(perform: onAppear)
        .onExitCommand(perform: handleExitCommand)
        .onChange(of: filterText) { _ in
            selectedIndex = 0
            clampSelectedIndex()
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
            .onChange(of: selectedIndex) { newIndex in
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
            VStack(alignment: .leading, spacing: 4) {
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

    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        guard outputType == .screen, CMSampleBufferIsValid(sampleBuffer) else { return }
        continuation?.resume(returning: sampleBuffer)
        continuation = nil

        Task { try? await stream.stopCapture() }
    }
}

private extension WindowSwitcherView {
    func snapshot(of window: Window) async -> NSImage? {
        // Use cached snapshot if still valid
        if let cached = snapshotCache[window.id],
           Date().timeIntervalSince(cached.createdAt) < snapshotValidity {
            print("📦 Using cached snapshot for '\(window.title)'")
            return cached.image
        }

        do {
            print("📸 Snapshot requested for window '\(window.title)', pid=\(window.pid)")

            let content = try await SCShareableContent.current

            guard let scWindow = content.windows.first(where: {
                $0.owningApplication?.processID == window.pid &&
                $0.isOnScreen &&
                (window.title.isEmpty || ($0.title ?? "").localizedCaseInsensitiveContains(window.title))
            }) else {
                // fallback to old cached image if available
                if let cached = snapshotCache[window.id] {
                    return cached.image
                }
                return nil
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
                        print("❌ Failed to start capture: \(error)")
                        continuation.resume(returning: nil)
                    }
                }
            }) else {
                if let cached = snapshotCache[window.id] { return cached.image }
                return nil
            }

            guard let ciImage = ciImage(from: frame) else {
                if let cached = snapshotCache[window.id] { return cached.image }
                return nil
            }

            let rep = NSCIImageRep(ciImage: ciImage)
            let nsImage = NSImage(size: rep.size)
            nsImage.addRepresentation(rep)

            // Save to cache with timestamp
            snapshotCache[window.id] = CachedSnapshot(image: nsImage, createdAt: Date())
            print("✅ Snapshot captured for '\(window.title)' (\(rep.size.width)x\(rep.size.height))")
            return nsImage

        } catch {
            print("❌ Snapshot error: \(error)")
            if let cached = snapshotCache[window.id] { return cached.image }
            return nil
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
        let listToShow = filterText.isEmpty ? (windows.isEmpty ? cachedWindows : windows) : filteredWindows
        return listToShow
    }
}

// MARK: - Lifecycle

private extension WindowSwitcherView {
    func onAppear() {
        isFocused = true
        observePanelFocus()
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
        guard !filteredWindows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % filteredWindows.count
    }

    func moveSelectionBackward() {
        guard !filteredWindows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + filteredWindows.count) % filteredWindows.count
    }

    func handleEnter() {
        if let command = extractCommand(from: filterText) {
            handleCommand(command)
            filterText = ""
            return
        }
        selectWindow()
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
        guard filteredWindows.indices.contains(selectedIndex) else { return }
        let window = filteredWindows[selectedIndex]
        focusWindow(window)
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

                //  Prepopulate snapshots to avoid blue icon flash
                Task {
                    for window in newWindows {
                        if snapshotCache[window.id] == nil {
                            _ = await snapshot(of: window)
                        }
                    }
                }
            }
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
        if displayedWindows.isEmpty {
            selectedIndex = 0
        } else if selectedIndex >= displayedWindows.count {
            selectedIndex = displayedWindows.count - 1
        }
    }
}

// MARK: - Utilities

private extension WindowSwitcherView {
    func fuzzyScore(text: String, pattern: String) -> Int {
        let textLower = text.lowercased()
        let patternLower = pattern.lowercased()
        
        if textLower.contains(patternLower) { return 100 }
        
        var score = 0
        var lastIndex = textLower.startIndex
        for char in patternLower {
            if let idx = textLower[lastIndex...].firstIndex(of: char) {
                score += 1
                lastIndex = textLower.index(after: idx)
            } else {
                break
            }
        }
        return score
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
