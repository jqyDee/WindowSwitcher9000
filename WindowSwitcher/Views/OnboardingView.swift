//
//  OnboardingView.swift
//  WindowSwitcher
//
//  The setup window, in three steps: Accessibility, hotkeys and window service, preview.
//

import SwiftUI
import ApplicationServices
import Combine
import KeyboardShortcuts

struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case accessibility, setup, preview
    }

    /// Only the Accessibility step: setup was done before, but the permission went missing.
    var accessibilityOnly = false
    var onDone: () -> Void

    @State private var step: Step = .accessibility
    // Polled: macOS posts no notification when a permission changes
    @State private var hasAccessibility = AXIsProcessTrusted()
    @State private var hasScreenRecording = CGPreflightScreenCaptureAccess()
    @State private var requestedScreenRecording = false
    @State private var hasSwitcherHotkey = KeyboardShortcuts.getShortcut(for: .openHotkeyWindow) != nil
    @AppStorage("PreviewEnabled") private var previewEnabled = true
    private let statusTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var steps: [Step] { accessibilityOnly ? [.accessibility] : Step.allCases }
    private var isLastStep: Bool { step == steps.last }

    var body: some View {
        VStack(spacing: 0) {
            header

            Group {
                switch step {
                case .accessibility: AccessibilityStep(isGranted: hasAccessibility)
                case .setup: SetupStep(hasSwitcherHotkey: $hasSwitcherHotkey)
                case .preview:
                    PreviewStep(
                        previewEnabled: $previewEnabled,
                        hasScreenRecording: hasScreenRecording,
                        requestedScreenRecording: $requestedScreenRecording
                    )
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .transition(.opacity)
            .id(step)

            footer
        }
        .frame(width: 560, height: 640)
        .animation(.easeInOut(duration: 0.2), value: step)
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
                    .frame(width: 64, height: 64)
            }
            Text(accessibilityOnly ? "WindowSwitcher Needs Accessibility" : "Welcome to WindowSwitcher")
                .font(.title)
                .bold()
            if steps.count > 1 {
                HStack(spacing: 6) {
                    ForEach(steps, id: \.self) { item in
                        Capsule()
                            .fill(item == step ? Color.accentColor : Color.primary.opacity(0.2))
                            .frame(width: item == step ? 18 : 6, height: 6)
                    }
                }
                .animation(.snappy, value: step)
                .padding(.top, 4)
            }
        }
        .padding(.top, 32)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        HStack {
            if step != steps.first {
                Button("Back") { move(by: -1) }
                    .controlSize(.large)
            }
            Text(footerHint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer()
            Button(isLastStep ? "Finish" : "Continue") {
                isLastStep ? onDone() : move(by: 1)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(!canContinue)
        }
        .padding(20)
    }

    private var canContinue: Bool {
        switch step {
        case .accessibility: return hasAccessibility
        // without a hotkey there is no way to open the switcher
        case .setup: return hasSwitcherHotkey
        case .preview: return true
        }
    }

    private var footerHint: String {
        switch step {
        case .accessibility: return hasAccessibility ? "" : "Accessibility is required to continue."
        case .setup: return hasSwitcherHotkey ? "" : "Record a hotkey to open the switcher."
        case .preview:
            return previewEnabled && !hasScreenRecording
                ? "You can finish now; previews appear once Screen Recording is on."
                : "You can change all of this later in Settings."
        }
    }

    private func move(by offset: Int) {
        guard let index = steps.firstIndex(of: step), steps.indices.contains(index + offset) else { return }
        step = steps[index + offset]
    }
}

// MARK: - Steps

private struct AccessibilityStep: View {
    let isGranted: Bool

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    title: "Accessibility",
                    systemImage: "accessibility",
                    explanation: "Lets WindowSwitcher list your windows and switch to the one you pick.",
                    isGranted: isGranted,
                    actionTitle: "Grant…",
                    action: { OnboardingHandler.shared.requestAccessibility() }
                )
            } footer: {
                Text("macOS asks you to switch WindowSwitcher on in System Settings → Privacy & Security → Accessibility. This page notices it by itself.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct SetupStep: View {
    @Binding var hasSwitcherHotkey: Bool
    @AppStorage("WindowService") private var windowService = "yabai"
    /// Which window managers are installed; `nil` until checked.
    @State private var installed: [String: Bool]?
    @State private var didPreselect = false

    private let services: [(key: String, name: String, explanation: String)] = [
        ("yabai", "yabai", "Sees windows on all spaces. Needs the yabai window manager."),
        ("aerospace", "AeroSpace", "Sees windows on all workspaces. Needs the AeroSpace window manager."),
        ("native", "Native", "Works without a window manager; sees the windows of the current space."),
    ]

    var body: some View {
        Form {
            Section {
                LabeledContent("Open Switcher") {
                    KeyboardShortcuts.Recorder(for: .openHotkeyWindow) { hasSwitcherHotkey = $0 != nil }
                }
                LabeledContent("Open Calculator") {
                    KeyboardShortcuts.Recorder(for: .openCalculator)
                }
                LabeledContent("Open Clipboard History") {
                    KeyboardShortcuts.Recorder(for: .openClipboardHistory)
                }
            } header: {
                Text("Hotkeys")
            } footer: {
                Text("The switcher hotkey is required. Calculator and clipboard history can also be reached by typing $ or # in the switcher.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Window Service") {
                ForEach(services, id: \.key) { service in
                    serviceRow(service)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .task { await detectInstalledServices() }
    }

    private func serviceRow(_ service: (key: String, name: String, explanation: String)) -> some View {
        let isSelected = windowService == service.key
        let isMissing = installed?[service.key] == false
        return Button { windowService = service.key } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(service.name)
                        if isMissing {
                            Text("not installed")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Text(service.explanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Checks for the yabai and AeroSpace command-line tools, and on first look preselects one that is
    /// installed (Native when neither is).
    private func detectInstalledServices() async {
        let result = await Task.detached {
            ["yabai", "aerospace"].reduce(into: ["native": true]) { found, name in
                found[name] = FileManager.default.isExecutableFile(atPath: ExecutableResolver.resolve(name).path)
            }
        }.value
        installed = result
        guard !didPreselect else { return }
        didPreselect = true
        if result[windowService] != true {
            windowService = result["yabai"] == true ? "yabai" : result["aerospace"] == true ? "aerospace" : "native"
        }
    }
}

private struct PreviewStep: View {
    @Binding var previewEnabled: Bool
    let hasScreenRecording: Bool
    @Binding var requestedScreenRecording: Bool

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    PreviewChoice(title: "With Preview", showsPreview: true, isSelected: previewEnabled) {
                        previewEnabled = true
                    }
                    PreviewChoice(title: "No Preview", showsPreview: false, isSelected: !previewEnabled) {
                        previewEnabled = false
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Window Preview")
            } footer: {
                Text(previewEnabled
                     ? "Shows a live picture of the selected window next to the list. Needs the Screen Recording permission."
                     : "Just the list. No extra permission needed; you can turn previews on later in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // the permission only matters with previews; without them, don't ask for it at all
            if previewEnabled {
                Section {
                    PermissionRow(
                        title: "Screen Recording",
                        systemImage: "rectangle.dashed.badge.record",
                        explanation: "Used only to picture the selected window.",
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
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .animation(.easeInOut(duration: 0.2), value: previewEnabled)
    }
}

/// A selectable card with a miniature of the panel, with or without the preview pane.
private struct PreviewChoice: View {
    let title: String
    let showsPreview: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                PanelMiniature(showsPreview: showsPreview)
                    .frame(height: 110)
                HStack(spacing: 6) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    Text(title)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(isSelected ? 0.08 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The switcher panel drawn small: search bar, list rows and, optionally, the preview pane with a window.
private struct PanelMiniature: View {
    let showsPreview: Bool
    private let line = Color.primary.opacity(0.18)

    var body: some View {
        VStack(spacing: 5) {
            Capsule()
                .fill(line)
                .frame(height: 12)
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(0..<4) { index in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(line).frame(width: 9, height: 9)
                            RoundedRectangle(cornerRadius: 2).fill(line).frame(width: index == 0 ? 38 : 28, height: 5)
                            Spacer(minLength: 0)
                        }
                        .padding(3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(index == 0 ? Color.accentColor.opacity(0.35) : .clear)
                        )
                    }
                    Spacer(minLength: 0)
                }
                if showsPreview {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.06))
                        .overlay(
                            VStack(spacing: 0) {
                                Rectangle().fill(line).frame(height: 6)
                                Rectangle().fill(Color.accentColor.opacity(0.15))
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .padding(7)
                        )
                }
            }
            .padding(5)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
        }
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
