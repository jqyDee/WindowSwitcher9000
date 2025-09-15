//
//  IconCache.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//


// Services/IconCache.swift
import Cocoa

public final class IconCache {
    public static let shared = IconCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {}

    public func iconForBundleIdentifier(_ bundleID: String?) -> NSImage? {
        guard let bundleID = bundleID else { return nil }
        if let cached = cache.object(forKey: bundleID as NSString) { return cached }

        // Try running apps first
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first, let icon = running.icon {
            icon.size = NSSize(width: 64, height: 64)
            cache.setObject(icon, forKey: bundleID as NSString)
            return icon
        }

        // Try finding app on disk
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 64, height: 64)
            cache.setObject(icon, forKey: bundleID as NSString)
            return icon
        }

        return nil
    }

    public func setIcon(_ image: NSImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}
