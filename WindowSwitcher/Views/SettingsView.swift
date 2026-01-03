//
//  SettingsView.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import SwiftUI
import KeyboardShortcuts

enum SettingsCategory: String, CaseIterable, Identifiable {
    case about = "About"
    case general = "General"
    case appearance = "Appearance"
    case privacy = "Privacy"
    case advanced = "Advanced"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .about: return "info.circle"
        case .general: return "gearshape"
        case .appearance: return "paintpalette"
        case .privacy: return "hand.raised"
        case .advanced: return "hammer"
        }
    }
}

struct SettingsView: View {
    @State private var selectedCategory: SettingsCategory? = .general
    
    var body: some View {
        NavigationSplitView {
            // Using the view builder version of List to allow for Dividers
            List(selection: $selectedCategory) {
                // 1. Static entry for About
                NavigationLink(value: SettingsCategory.about) {
                    Label(SettingsCategory.about.rawValue, systemImage: SettingsCategory.about.icon)
                }
                
                // 2. The Separator
                Divider()
                
                // 3. Dynamic entries for the rest
                ForEach(SettingsCategory.allCases.filter { $0 != .about }) { category in
                    NavigationLink(value: category) {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 160, max: 160)
        } detail: {
            Group {
                switch selectedCategory {
                case .about: AboutView()
                case .general: GeneralSettingsView()
                case .appearance: AppearanceSettingsView()
                case .privacy: PrivacySettingsView()
                case .advanced: AdvancedSettingsView()
                case .none: Text("Select a category")
                }
            }
            .navigationTitle(selectedCategory?.rawValue ?? "")
        }
        .frame(width: 700, height: 450)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SelectAboutCategory"))) { _ in
            selectedCategory = .about
        }
    }
}

// MARK: - Subviews

struct GeneralSettingsView: View {
    @AppStorage("DockHidden") private var isDockHidden = true
    @AppStorage("EnableNotifications") private var enableNotifications = false
    
    var body: some View {
        Form {
            Section("Keyboard") {
                LabeledContent("Open Switcher") {
                    KeyboardShortcuts.Recorder(for: .openHotkeyWindow)
                }
            }
            Section("System") {
                Toggle("Hide Dock Icon", isOn: $isDockHidden)
                    .onChange(of: isDockHidden) { _, newValue in
                        MenuBarHandler.shared.toggleDockIconProgrammatically()
                    }
                Toggle("Enable Notifications", isOn: $enableNotifications)
            }
        }
        .formStyle(.grouped)
    }
}

struct AppearanceSettingsView: View {
    @AppStorage("PanelWidth") private var panelWidth = 900.0
    @AppStorage("PanelHeight") private var panelHeight = 400.0
    @AppStorage("PreviewWidthPercentage") private var previewRatio = 0.55
    @AppStorage("PreviewEnabled") private var previewEnabled = true
    
    var body: some View {
        Form {
            Section("Dimensions") {
                LabeledContent("Width") {
                    HStack {
                        Slider(value: $panelWidth, in: 600...1200, step: 10)
                        
                        Text("\(Int(panelWidth)) px")
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }

                LabeledContent("Height") {
                    HStack {
                        Slider(value: $panelHeight, in: 300...600, step: 10)
                        
                        Text("\(Int(panelHeight)) px")
                            .monospacedDigit() .frame(width: 60, alignment: .trailing)
                    }
                }
            }
            
            Section("Preview") {
                Toggle("Enable Preview", isOn: $previewEnabled)
                
                LabeledContent("Ratio") {
                    HStack {
                        Slider(value: $previewRatio, in: 0.3...0.71, step: 0.02)
                        
                        Text("\(Int(previewRatio * 100))%")
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                .disabled(!previewEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section("Permissions") {
                LabeledContent("Accessibility") {
                    PermissionButton(
                        isGranted: MenuBarHandler.shared.checkAccessibilityPermission(),
                        action: { MenuBarHandler.shared.requestAccessibilityPermission(NSMenuItem()) }
                    )
                }
                LabeledContent("Screen Recording") {
                    PermissionButton(
                        isGranted: MenuBarHandler.shared.checkScreenRecordingPermission(),
                        action: { _ = MenuBarHandler.shared.checkScreenRecordingPermission() }
                    )
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("IsDebugMode") private var isDebugMode = false
    
    var body: some View {
        Form {
            Section("Maintenance") {
                LabeledContent("Panel Location") {
                    Button("Reset") { MenuBarHandler.shared.resetPanelFrame() }
                }
                LabeledContent("Search History") {
                    Button("Clear", role: .destructive) { MenuBarHandler.shared.clearHistory() }
                }
            }
            Section("Testing") {
                Toggle("Debug Mode", isOn: $isDebugMode)
            }
        }
        .formStyle(.grouped)
    }
}

struct PermissionButton: View {
    let isGranted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isGranted ? .green : .red)
                Text(isGranted ? "Granted" : "Check Status")
            }
        }
    }
}

struct AboutView: View {
    // Fetches the 'Marketing Version' (e.g., 1.0.0)
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }
    
    // Fetches the 'Build' number (e.g., 42)
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 80, height: 80)
            }

            VStack(spacing: 4) {
                Text("WindowSwitcher")
                    .font(.title)
                    .bold()
                
                Text("Version \(version) (Build \(build))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("A fast, keyboard-centric window switcher for macOS, powered by Yabai.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Divider().frame(width: 200)

            VStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/jqyDee/WindowSwitcher9000")!) {
                    Label("View on GitHub", systemImage: "link")
                }
                
                Text("© 2026 Matti Fischbach")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension KeyboardShortcuts.Name {
    static let openHotkeyWindow = Self("openHotkeyWindow")
}
