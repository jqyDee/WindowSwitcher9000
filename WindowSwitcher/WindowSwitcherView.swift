//
//  ContentView.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

struct Window: Identifiable, Decodable {
    let id: Int
    let app: String
    let title: String
}

import SwiftUI

struct WindowSwitcherView: View {
    @State private var filterText: String = ""
    
    @State private var windows: [Window] = []
    @State private var cachedWindows: [Window] = []

    @State private var selectedIndex: Int = 0
    
    @FocusState var isFocused
    
    var onClose: (([Window]) -> Void)?
    
    init(initialWindows: [Window] = [], onClose: (([Window]) -> Void)? = nil) {
        _windows = State(initialValue: initialWindows)
        self.onClose = onClose
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayedWindows.indices, id: \.self) { index in
                            let window = displayedWindows[index]
                            Button(action: { focusWindow(window) }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(window.title.isEmpty ? "(Untitled)" : window.title)
                                        .font(.headline)
                                    Text(window.app)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(index == selectedIndex ? Color.white.opacity(0.15) : .clear)
                                )
                            }
                            .buttonStyle(.plain)
                            .id(index) // IMPORTANT: give each row a unique ID for scrolling
                        }
                    }
                    .padding([.horizontal])
                }
                .onChange(of: selectedIndex) { newIndex in
                    // Scroll to the currently selected row
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            
            // Bottom HStack pinned
            VStack(spacing: 0) {
                Divider()
                    .background(Color(white: 0.5).opacity(0.5))
                    .frame(height: 0.08)
                
                HStack {
                    Button(action: { handleEscape() }) {
                        Image(systemName: "rectangle.3.offgrid")
                            .resizable()
                            .frame(width: 12, height: 12)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer() // pushes everything else to the right if needed
                    
                    Text("WindowSwitcher9000")
                }
                .padding(.horizontal)
                .frame(height: 30) // the total height of the bottom bar
                .frame(maxWidth: .infinity, alignment: .leading) // align content to left
            }
            .background(
                VisualEffectBlur(darkeningOpacity: 0.4)
            )
        }
        .background(
            VisualEffectBlur(darkeningOpacity: 0.25)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .foregroundStyle(.primary)
        .frame(width: 750, height: 300)
        .onAppear() {
            isFocused = true
            print("WindowSwitcher : loaded cached windows")
            cachedWindows = windows
            refreshWindows()
        }
        .onExitCommand {
            if !filterText.isEmpty {
                filterText = ""  // clear the search field first
            } else {
                onClose?(windows)       // close the panel if the field is already empty
            }
        }
        .onChange(of: filterText) { _ in
            // reset selection whenever the filter changes
            selectedIndex = 0
        }
    }
    
    private var filteredWindows: [Window] {
        if filterText.isEmpty {
            return windows
        } else {
            return windows
                .map { ($0, fuzzyScore(text: $0.title + " " + $0.app, pattern: filterText)) }
                .filter { $0.1 > 0 }  // keep only matches
                .sorted { $0.1 > $1.1 }  // highest score first
                .map { $0.0 }
        }
    }
    
    private var displayedWindows: [Window] {
        if windows.isEmpty && !cachedWindows.isEmpty {
            return cachedWindows
        } else {
            return filteredWindows
        }
    }
    
    private func moveSelectionForward() {
        guard !filteredWindows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % filteredWindows.count
    }

    private func moveSelectionBackward() {
        guard !filteredWindows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + filteredWindows.count) % filteredWindows.count
    }

    private func handleEnter() {
        print("WindowSwitcher : enter on selected = \(selectedIndex)")
        selectWindow()
    }

    private func handleEscape() {
        print("WindowSwitcher : esc-pressed")
        if !filterText.isEmpty {
            print("WindowSwitcher : filter = \"\"")
            filterText = ""
        } else {
            print("WindowSwitcher : closing")
            onClose?(windows)
        }
    }
    
    private func selectWindow() {
        guard filteredWindows.indices.contains(selectedIndex) else { return }
        let window = filteredWindows[selectedIndex]
        focusWindow(window)
        onClose?(windows)
    }
    
    private func loadWindows() -> [Window] {
        print("WindowSwitcher : loading windows")
        let task = Process()
        
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", "/opt/homebrew/bin/yabai -m query --windows | jq -c '.[] | {id: .id, app: .app, title: .title}'"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        var newWindows: [Window] = []
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            print("WindowSwitcher : yabai call succesful")
            let lines = output.split(separator: "\n").map { String($0) }
            let decoder = JSONDecoder()
            newWindows = lines.compactMap { line in
                line.data(using: .utf8).flatMap { try? decoder.decode(Window.self, from: $0) }
            }
        } else {
            print("WindowSwitcher : yabai call unsuccesful")
            newWindows = [
                Window(id: 1, app: "Dummy1", title: "Wooow"),
                Window(id: 2, app: "Dummy2", title: "Wooow"),
                Window(id: 3, app: "Dummy3", title: "Wooow"),
            ]
        }
        return newWindows
    }
    
    private func refreshWindows() {
        print("WindowSwitcher : refreshing windows")
        DispatchQueue.global(qos: .userInitiated).async {
            var newWindows = loadWindows()

            // Sort windows by app name, then title
            newWindows.sort { lhs, rhs in
                if lhs.app != rhs.app {
                    return lhs.app < rhs.app
                } else {
                    return lhs.title < rhs.title
                }
            }

            DispatchQueue.main.async {
                self.windows = newWindows
                print("WindowSwitcher : exchanged new windows (sorted)")
            }
        }
    }

    
    private func focusWindow(_ window: Window) {
        print("WindowSwitcher : focusing window \(window)")
        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", "/opt/homebrew/bin/yabai -m window --focus \(window.id)"]
        task.launch()
    }
    
    private func fuzzyScore(text: String, pattern: String) -> Int {
        let patternLower = pattern.lowercased()
        let textLower = text.lowercased()
        
        // Perfect match
        if textLower.contains(patternLower) { return 100 }
        
        // Partial matching: count matching characters in order
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
    
    private struct VisualEffectBlur: NSViewRepresentable {
        var darkeningOpacity: CGFloat = 0.4   // 0 = no darkening, 1 = fully black

        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.blendingMode = .behindWindow
            view.material = .menu // or .menu, .sidebar, etc.
            view.state = .active
            
            // Add a dark overlay inside the NSVisualEffectView
            let darkOverlay = NSView()
            darkOverlay.wantsLayer = true
            darkOverlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(darkeningOpacity).cgColor
            darkOverlay.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(darkOverlay)
            
            // Pin overlay to fill the effect view
            NSLayoutConstraint.activate([
                darkOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                darkOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                darkOverlay.topAnchor.constraint(equalTo: view.topAnchor),
                darkOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            
            return view
        }

        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
            // Optionally update overlay opacity dynamically
            if let overlay = nsView.subviews.first {
                overlay.layer?.backgroundColor = NSColor.black.withAlphaComponent(darkeningOpacity).cgColor
            }
        }
    }
}

#Preview {
    WindowSwitcherView()
}
