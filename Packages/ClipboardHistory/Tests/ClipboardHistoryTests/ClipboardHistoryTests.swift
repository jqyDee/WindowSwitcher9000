import Foundation
import Testing
@testable import ClipboardHistory

/// A store in a fresh temporary folder, removed after the test.
final class TemporaryStore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClipboardHistoryTests-\(UUID().uuidString)", isDirectory: true)
    lazy var store = ClipboardStore(directory: directory)

    func reopened() -> ClipboardStore { ClipboardStore(directory: directory) }
    func imageFiles() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.appendingPathComponent("images").path)) ?? []
    }

    deinit { try? FileManager.default.removeItem(at: directory) }
}

private let pngBytes = Data([0x89, 0x50, 0x4E, 0x47, 1, 2, 3])
private let otherBytes = Data([0x89, 0x50, 0x4E, 0x47, 9, 9, 9])
private let fileA = URL(fileURLWithPath: "/tmp/a.txt")
private let fileB = URL(fileURLWithPath: "/tmp/b.pdf")

@Suite("Fingerprints")
struct FingerprintTests {
    @Test func sameContentSameFingerprint() {
        #expect(ClipContent.text("hello").fingerprint == ClipContent.text("hello").fingerprint)
        #expect(ClipContent.image(pngBytes, format: .png).fingerprint == ClipContent.image(pngBytes, format: .png).fingerprint)
        #expect(ClipContent.files([fileA, fileB]).fingerprint == ClipContent.files([fileA, fileB]).fingerprint)
        // the same path written differently is the same file
        #expect(ClipContent.files([URL(fileURLWithPath: "/tmp/./a.txt")]).fingerprint == ClipContent.files([fileA]).fingerprint)
    }

    @Test func differentContentDifferentFingerprint() {
        let fingerprints = [
            ClipContent.text("hello"), .text("Hello"), .text("hello "), .text(""),
            .image(pngBytes, format: .png), .image(otherBytes, format: .png),
            .files([fileA]), .files([fileB]), .files([fileA, fileB]), .files([fileB, fileA]),
            // text equal to a file path is still text
            .text("/tmp/a.txt"),
        ].map(\.fingerprint)
        #expect(Set(fingerprints).count == fingerprints.count)
    }

    @Test func fingerprintIsHexSHA256() {
        let fingerprint = ClipContent.text("x").fingerprint
        #expect(fingerprint.count == 64)
        #expect(fingerprint.allSatisfy { $0.isHexDigit })
    }
}

@Suite("Recording")
struct RecordingTests {
    @Test func newestFirst() {
        let t = TemporaryStore()
        t.store.record(.text("one"), sourceApp: "A", limit: 10)
        t.store.record(.text("two"), sourceApp: "B", limit: 10)
        #expect(t.store.items.map(\.text) == ["two", "one"])
        #expect(t.store.items.map(\.sourceApp) == ["B", "A"])
    }

    @Test("Copying content again moves its entry to the top instead of adding a duplicate")
    func duplicateMovesToTop() {
        let t = TemporaryStore()
        let first = t.store.record(.text("one"), sourceApp: "A", date: Date(timeIntervalSince1970: 1), limit: 10)
        t.store.record(.text("two"), sourceApp: "A", limit: 10)
        let again = t.store.record(.text("one"), sourceApp: "B", date: Date(timeIntervalSince1970: 5), limit: 10)

        #expect(t.store.items.map(\.text) == ["one", "two"])
        #expect(again.id == first.id)
        #expect(t.store.items[0].date == Date(timeIntervalSince1970: 5))
        #expect(t.store.items[0].sourceApp == "B")
    }

    @Test("Re-copying without a known source keeps the original source")
    func duplicateKeepsSource() {
        let t = TemporaryStore()
        t.store.record(.text("one"), sourceApp: "Safari", limit: 10)
        t.store.record(.text("one"), sourceApp: nil, limit: 10)
        #expect(t.store.items[0].sourceApp == "Safari")
    }

    @Test func duplicateImageWritesNoSecondFile() {
        let t = TemporaryStore()
        t.store.record(.image(pngBytes, format: .png), sourceApp: nil, limit: 10)
        t.store.record(.text("between"), sourceApp: nil, limit: 10)
        t.store.record(.image(pngBytes, format: .png), sourceApp: nil, limit: 10)
        #expect(t.store.items.count == 2)
        #expect(t.imageFiles().count == 1)
    }

    @Test func kinds() throws {
        let t = TemporaryStore()
        t.store.record(.files([fileA, fileB]), sourceApp: "Finder", limit: 10)
        t.store.record(.image(pngBytes, format: .tiff), sourceApp: "Preview", limit: 10)
        t.store.record(.text("hello"), sourceApp: nil, limit: 10)

        let text = t.store.items[0], image = t.store.items[1], files = t.store.items[2]
        #expect(text.kind == .text && text.text == "hello")
        #expect(image.kind == .image && image.imageFileName?.hasSuffix(".tiff") == true)
        #expect(try Data(contentsOf: try #require(t.store.imageURL(for: image))) == pngBytes)
        #expect(files.kind == .files && files.fileURLs == [fileA, fileB])
        #expect(t.store.imageURL(for: text) == nil)
    }
}

@Suite("Limits and deletion")
struct LimitTests {
    @Test("Recording past the limit drops the oldest entries")
    func limitDropsOldest() {
        let t = TemporaryStore()
        for i in 1...5 { t.store.record(.text("\(i)"), sourceApp: nil, limit: 3) }
        #expect(t.store.items.map(\.text) == ["5", "4", "3"])
    }

    @Test("A duplicate at the limit does not push anything out")
    func duplicateAtLimit() {
        let t = TemporaryStore()
        for i in 1...3 { t.store.record(.text("\(i)"), sourceApp: nil, limit: 3) }
        t.store.record(.text("1"), sourceApp: nil, limit: 3)
        #expect(t.store.items.map(\.text) == ["1", "3", "2"])
    }

    @Test func trimDeletesImageFiles() {
        let t = TemporaryStore()
        t.store.record(.image(pngBytes, format: .png), sourceApp: nil, limit: 10)
        t.store.record(.image(otherBytes, format: .png), sourceApp: nil, limit: 10)
        t.store.record(.text("newest"), sourceApp: nil, limit: 10)
        #expect(t.imageFiles().count == 2)

        t.store.trim(to: 2)
        #expect(t.store.items.count == 2)
        #expect(t.imageFiles().count == 1)

        t.store.trim(to: 0)
        #expect(t.store.items.isEmpty)
        #expect(t.imageFiles().isEmpty)
    }

    @Test func removeDeletesOnlyThatEntry() {
        let t = TemporaryStore()
        let image = t.store.record(.image(pngBytes, format: .png), sourceApp: nil, limit: 10)
        t.store.record(.text("keep"), sourceApp: nil, limit: 10)
        t.store.remove(id: image.id)
        #expect(t.store.items.map(\.text) == ["keep"])
        #expect(t.imageFiles().isEmpty)
        t.store.remove(id: UUID()) // unknown id: no change
        #expect(t.store.items.count == 1)
    }

    @Test func clearDeletesEverything() {
        let t = TemporaryStore()
        t.store.record(.image(pngBytes, format: .png), sourceApp: nil, limit: 10)
        t.store.record(.text("x"), sourceApp: nil, limit: 10)
        t.store.clear()
        #expect(t.store.items.isEmpty)
        #expect(t.imageFiles().isEmpty)
        #expect(t.reopened().items.isEmpty)
    }
}

@Suite("Persistence")
struct PersistenceTests {
    @Test func survivesReopening() {
        let t = TemporaryStore()
        t.store.record(.files([fileA]), sourceApp: "Finder", limit: 10)
        t.store.record(.image(pngBytes, format: .png), sourceApp: nil, limit: 10)
        t.store.record(.text("line one\nline two"), sourceApp: "Notes", limit: 10)

        let reopened = t.reopened()
        #expect(reopened.items == t.store.items)
        #expect(reopened.imageURL(for: reopened.items[1]).flatMap { try? Data(contentsOf: $0) } == pngBytes)
    }

    @Test("Duplicates are recognized across launches")
    func duplicateAfterReopening() {
        let t = TemporaryStore()
        t.store.record(.text("one"), sourceApp: nil, limit: 10)
        t.store.record(.text("two"), sourceApp: nil, limit: 10)
        let reopened = t.reopened()
        reopened.record(.text("one"), sourceApp: nil, limit: 10)
        #expect(reopened.items.map(\.text) == ["one", "two"])
    }

    @Test("A corrupt index starts an empty history instead of failing")
    func corruptIndex() throws {
        let t = TemporaryStore()
        t.store.record(.text("x"), sourceApp: nil, limit: 10)
        try Data("not json".utf8).write(to: t.directory.appendingPathComponent("index.json"))
        let reopened = t.reopened()
        #expect(reopened.items.isEmpty)
        reopened.record(.text("y"), sourceApp: nil, limit: 10)
        #expect(t.reopened().items.map(\.text) == ["y"])
    }
}

@Suite("Display and search")
struct DisplayTests {
    func item(_ content: ClipContent, source: String? = nil) -> ClipItem {
        TemporaryStore().store.record(content, sourceApp: source, limit: 10)
    }

    @Test func titles() {
        #expect(item(.text("  \n\n  first line  \nsecond")).title == "first line")
        #expect(item(.text("   ")).title == "")
        #expect(item(.image(pngBytes, format: .png)).title == "Image")
        #expect(item(.files([fileA])).title == "a.txt")
        #expect(item(.files([fileA, fileB])).title == "2 Files: a.txt, b.pdf")
    }

    @Test func search() {
        let text = item(.text("The Quick Brown Fox"))
        #expect(text.matches("quick brown"))
        #expect(text.matches(""))
        #expect(text.matches("  fox "))
        #expect(!text.matches("dog"))

        let files = item(.files([fileA, fileB]))
        #expect(files.matches("b.pdf"))
        #expect(!files.matches("tmp")) // matches file names, not folders

        let image = item(.image(pngBytes, format: .png), source: "Preview")
        #expect(image.matches("image"))
        #expect(image.matches("preview"))
    }
}
