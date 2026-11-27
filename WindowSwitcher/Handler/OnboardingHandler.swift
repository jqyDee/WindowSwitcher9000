//
//  OnboardingHandler.swift
//  WindowSwitcher
//

import SwiftUI
import AppKit
import ApplicationServices

/// Owns the setup window shown on first launch (and whenever the required Accessibility permission is missing).
@MainActor
final class OnboardingHandler {
    static let shared = OnboardingHandler()

    private static let completedKey = "HasCompletedOnboarding"
    private var window: NSWindow?

    private init() {}

    var shouldShowOnLaunch: Bool {
        !UserDefaults.standard.bool(forKey: Self.completedKey) || !AXIsProcessTrusted()
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: OnboardingView(onDone: { [weak self] in self?.complete() }))
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Welcome to WindowSwitcher"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .managed]
        window.center()

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.window = nil }
        }
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: Self.completedKey)
        window?.close()
    }

    /// Shows the system Accessibility prompt, which links to System Settings.
    func requestAccessibility() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// macOS only applies a newly granted Screen Recording permission after the app restarts.
    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
