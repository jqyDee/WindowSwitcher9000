//
//  SettingsView.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @AppStorage("PanelWidth") private var panelWidth = 900.0
    @AppStorage("PanelHeight") private var panelHeight = 400.0
    @AppStorage("PreviewWidthPercentage") private var previewRatio = 0.55
    @AppStorage("PreviewEnabled") private var previewEnabled = true
    @AppStorage("IsDebugMode") private var isDebugMode = false
    @AppStorage("DockHidden") private var isDockHidden = true
    
    var body: some View {
        Form {
            Section("Keyboard") {
                LabeledContent("Open Switcher") {
                    KeyboardShortcuts.Recorder(for: .openHotkeyWindow)
                }
            }
            
            Section("Appearance") {
                LabeledContent("Panel Width") {
                    HStack {
                        Slider(value: $panelWidth, in: 600...1200, step: 10)
                        Text("\(Int(panelWidth))px")
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                
                LabeledContent("Panel Height") {
                    HStack {
                        Slider(value: $panelHeight, in: 300...600, step: 10)
                        Text("\(Int(panelHeight))px")
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }
                
                LabeledContent("Preview Ratio") {
                    HStack {
                        Slider(value: $previewRatio, in: 0.3...0.71, step: 0.02)
                        Text("\(Int(previewRatio * 100))%")
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
            
            Section("Privacy & Permissions") {
                LabeledContent("Accessibility") {
                    let isGranted = MenuBarHandler.shared.checkAccessibilityPermission()
                    Button(action: { MenuBarHandler.shared.requestAccessibilityPermission(NSMenuItem()) }) {
                        HStack(spacing: 4) {
                            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isGranted ? .green : .red)
                            Text(isGranted ? "Granted" : "Request...")
                        }
                    }
                }
                
                LabeledContent("Screen Recording") {
                    let isGranted = MenuBarHandler.shared.checkScreenRecordingPermission()
                    Button(action: { _ = MenuBarHandler.shared.checkScreenRecordingPermission() }) {
                        HStack(spacing: 4) {
                            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isGranted ? .green : .red)
                            Text(isGranted ? "Granted" : "Check Status")
                        }
                    }
                }
            }
            
            Section("Maintenance") {
                // Placing maintenance buttons in LabeledContent keeps them aligned with sliders/toggles
                LabeledContent("Window State") {
                    Button("Reset Panel Location") {
                        MenuBarHandler.shared.resetPanelFrame()
                    }
                }
                
                LabeledContent("Data") {
                    Button("Clear Search History", role: .destructive) {
                        MenuBarHandler.shared.clearHistory()
                    }
                }
            }
            
            Section("Features") {
                Toggle("Enable Preview", isOn: $previewEnabled)
                Toggle("Debug Mode", isOn: $isDebugMode)
                Toggle("Hide Dock Icon", isOn: $isDockHidden)
                    .onChange(of: isDockHidden) { _, newValue in
                        if newValue != MenuBarHandler.shared.isDockHidden {
                            MenuBarHandler.shared.toggleDockIconProgrammatically()
                        }
                    }
            }
            
            // Native Footer look: no divider, just spacing or a centered button
            HStack {
                Button("Reset to Defaults") {
                    panelWidth = 900.0
                    panelHeight = 400.0
                    previewRatio = 0.58
                    MenuBarHandler.shared.resetPanelFrame()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(width: 500)
    }
}

extension KeyboardShortcuts.Name {
    static let openHotkeyWindow = Self("openHotkeyWindow")
}
