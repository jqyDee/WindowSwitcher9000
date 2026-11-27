//
//  ClipItem.swift
//  ClipboardHistory
//

import Foundation

/// A stored clipboard entry. Images live in files next to the index; see `ClipboardStore.imageURL(for:)`.
public struct ClipItem: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case text, image, files
    }

    public let id: UUID
    public let kind: Kind
    public let fingerprint: String
    /// The text, for `.text` entries.
    public let text: String?
    /// The image's file name in the store's image folder, for `.image` entries.
    public let imageFileName: String?
    /// The copied files, for `.files` entries.
    public let fileURLs: [URL]?
    /// The app that was frontmost when it was copied, if known.
    public internal(set) var sourceApp: String?
    /// When it was last copied.
    public internal(set) var date: Date

    /// One line describing the entry, for lists.
    public var title: String {
        switch kind {
        case .text:
            let line = text?
                .split(whereSeparator: \.isNewline)
                .first { !$0.allSatisfy(\.isWhitespace) }
                .map { $0.trimmingCharacters(in: .whitespaces) }
            return line ?? ""
        case .image:
            return "Image"
        case .files:
            let names = (fileURLs ?? []).map(\.lastPathComponent)
            return names.count == 1 ? names[0] : "\(names.count) Files: " + names.joined(separator: ", ")
        }
    }

    /// What a search matches against.
    public var searchableText: String {
        switch kind {
        case .text: return text ?? ""
        case .image: return "Image " + (sourceApp ?? "")
        case .files: return (fileURLs ?? []).map(\.lastPathComponent).joined(separator: " ")
        }
    }

    public func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        return query.isEmpty || searchableText.localizedCaseInsensitiveContains(query)
    }
}
