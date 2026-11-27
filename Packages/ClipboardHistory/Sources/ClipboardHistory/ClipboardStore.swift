//
//  ClipboardStore.swift
//  ClipboardHistory
//
//  The persisted clipboard history: `index.json` plus one file per image in `images/`.
//  Content that is already in the history is moved to the top instead of stored twice.
//

import Foundation

public final class ClipboardStore {
    public let directory: URL
    /// Newest first.
    public private(set) var items: [ClipItem]

    private var indexURL: URL { directory.appendingPathComponent("index.json") }
    private var imagesURL: URL { directory.appendingPathComponent("images", isDirectory: true) }

    /// Loads the history from `directory`, creating it if needed. An unreadable index starts an empty history.
    public init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory.appendingPathComponent("images"),
                                                 withIntermediateDirectories: true)
        let data = try? Data(contentsOf: directory.appendingPathComponent("index.json"))
        items = data.flatMap { try? JSONDecoder().decode([ClipItem].self, from: $0) } ?? []
    }

    public func imageURL(for item: ClipItem) -> URL? {
        item.imageFileName.map { imagesURL.appendingPathComponent($0) }
    }

    /// Adds `content` at the top, or moves the entry already holding it there (updating its date and source).
    /// Then trims to `limit`.
    @discardableResult
    public func record(_ content: ClipContent, sourceApp: String?, date: Date = .now, limit: Int) -> ClipItem {
        let fingerprint = content.fingerprint
        if let index = items.firstIndex(where: { $0.fingerprint == fingerprint }) {
            var item = items.remove(at: index)
            item.date = date
            item.sourceApp = sourceApp ?? item.sourceApp
            items.insert(item, at: 0)
            save()
            return item
        }

        let id = UUID()
        let item: ClipItem
        switch content {
        case .text(let string):
            item = ClipItem(id: id, kind: .text, fingerprint: fingerprint, text: string, imageFileName: nil,
                            fileURLs: nil, sourceApp: sourceApp, date: date)
        case .image(let data, let format):
            let fileName = "\(id.uuidString).\(format.rawValue)"
            try? data.write(to: imagesURL.appendingPathComponent(fileName), options: .atomic)
            item = ClipItem(id: id, kind: .image, fingerprint: fingerprint, text: nil, imageFileName: fileName,
                            fileURLs: nil, sourceApp: sourceApp, date: date)
        case .files(let urls):
            item = ClipItem(id: id, kind: .files, fingerprint: fingerprint, text: nil, imageFileName: nil,
                            fileURLs: urls, sourceApp: sourceApp, date: date)
        }
        items.insert(item, at: 0)
        trim(to: limit)
        save()
        return item
    }

    /// Deletes the oldest entries beyond `limit`, with their image files.
    public func trim(to limit: Int) {
        guard items.count > max(limit, 0) else { return }
        let removed = items[max(limit, 0)...]
        removed.forEach(deleteFiles)
        items.removeSubrange(max(limit, 0)...)
        save()
    }

    public func remove(id: ClipItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        deleteFiles(of: items.remove(at: index))
        save()
    }

    public func clear() {
        items.forEach(deleteFiles)
        items = []
        save()
    }

    private func deleteFiles(of item: ClipItem) {
        if let url = imageURL(for: item) { try? FileManager.default.removeItem(at: url) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }
}
