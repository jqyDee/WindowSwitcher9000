//
//  OnboardingView.swift
//  WindowSwitcher
//

import SwiftUI
import ApplicationServices
import Combine
import KeyboardShortcuts

struct OnboardingView: View {
    var onDone: () -> Void

    // Polled: macOS posts no notification when a permission changes
    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var hasScreenRecording = CGPreflightScreenCaptureAccess()
    @State private var requestedScreenRecording = false
    private let statusTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header

            Form {
                Section("Required") {
                    PermissionRow(
                        title: "Accessibility",
                        systemImage: "accessibility",
                        explanation: "Lists your windows and focuses the one you pick.",
                        isGranted: hasAccessibility,
                        actionTitle: "Grant…",
                        action: { OnboardingHandler.shared.requestAccessibility() }
                    )
                }

                Section {
                    PermissionRow(
                        title: "Screen Recording",
                        systemImage: "rectangle.dashed.badge.record",
                        explanation: "Shows a live preview of the selected window.",
                        isGranted: hasScreenRecording,
                        actionTitle: "Open System Settings…",
                        action: {
                            requestedScreenRecording = true
                            MenuBarHandler.shared.requestScreenRecordingPermission()
                        }
                    )
                    if requestedScreenRecording && !hasScreenRecording {
                        LabeledContent {
                            Button("Restart WindowSwitcher") { OnboardingHandler.shared.relaunch() }
                        } label: {
                            Text("After switching WindowSwitcher on, restart the app so macOS applies the permission.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Optional")
                }

                Section("Shortcut") {
                    LabeledContent("Open Switcher") {
                        KeyboardShortcuts.Recorder(for: .openHotkeyWindow)
                    }
                }

                Section {
                    LabeledContent("Window Service") {
                        WindowServicePicker()
                    }
                } header: {
                    Text("Window Service")
                } footer: {
                    Text("yabai or AeroSpace see windows on all spaces. Native needs no window manager.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            HStack {
                Text(hasAccessibility ? "You can change all of this later in Settings." : "Accessibility is required to continue.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done", action: onDone)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!hasAccessibility)
            }
            .padding(20)
        }
        .frame(width: 540, height: 640)
        .onReceive(statusTimer) { _ in
            hasAccessibility = AXIsProcessTrusted()
            hasScreenRecording = CGPreflightScreenCaptureAccess()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 72, height: 72)
            }
            Text("Welcome to WindowSwitcher")
                .font(.title)
                .bold()
            Text("A few things to set up before you start switching.")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 36)
        .padding(.bottom, 4)
    }
}

private struct PermissionRow: View {
    let title: String
    let systemImage: String
    let explanation: String
    let isGranted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        LabeledContent {
            if isGranted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button(actionTitle, action: action)
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(explanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }
        }
    }
}
