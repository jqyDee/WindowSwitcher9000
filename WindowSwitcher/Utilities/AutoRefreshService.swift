//
//  AutoRefreshService.swift
//  WindowSwitcher
//
//  Created by Copilot on 2025-09-15.
//

import Foundation

/// A helper to manage periodic auto-refreshing tasks using Swift Concurrency.
///
/// Usage:
/// ```swift
/// let autoRefresher = AutoRefreshService(interval: 1.0) {
///     await refreshLogic()
/// }
/// autoRefresher.start()
/// // ... later
/// autoRefresher.stop()
/// ```
public final class AutoRefreshService {
    private let interval: TimeInterval
    private let refreshAction: @Sendable () async -> Void
    private var task: Task<Void, Never>?

    /// Initializes the service with a refresh interval and action.
    /// - Parameters:
    ///   - interval: The interval (in seconds) between refresh actions.
    ///   - refreshAction: The async action to perform on each tick.
    public init(interval: TimeInterval = 1.0, refreshAction: @escaping @Sendable () async -> Void) {
        self.interval = interval
        self.refreshAction = refreshAction
    }

    /// Starts the auto-refreshing task. If already running, cancels and restarts.
    public func start() {
        stop()
        task = Task.detached { [interval, refreshAction] in
            while !Task.isCancelled {
                await refreshAction()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    /// Stops the auto-refreshing task.
    public func stop() {
        task?.cancel()
        task = nil
    }

    deinit {
        stop()
    }
}
