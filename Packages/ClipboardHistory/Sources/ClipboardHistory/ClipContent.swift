//
//  ClipContent.swift
//  ClipboardHistory
//

import CryptoKit
import Foundation

/// Something read from the clipboard, before it is stored.
public enum ClipContent: Equatable, Sendable {
    case text(String)
    case image(Data, format: ImageFormat)
    case files([URL])

    public enum ImageFormat: String, Codable, Sendable {
        case png, tiff
    }

    /// Identifies the content: copying the same text, image or files again gives the same fingerprint,
    /// which is how the history recognizes something it already holds.
    public var fingerprint: String {
        var hasher = SHA256()
        switch self {
        case .text(let string):
            hasher.update(data: Data("text\0".utf8))
            hasher.update(data: Data(string.utf8))
        case .image(let data, _):
            // the format is not part of the identity: the same pixels as PNG or TIFF are different
            // bytes anyway, and the same bytes are the same image
            hasher.update(data: Data("image\0".utf8))
            hasher.update(data: data)
        case .files(let urls):
            hasher.update(data: Data("files\0".utf8))
            hasher.update(data: Data(urls.map(\.standardizedFileURL.path).joined(separator: "\0").utf8))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
