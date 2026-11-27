//
//  ClipboardHistoryView.swift
//  WindowSwitcher
//
//  Clipboard mode's results card: matching entries, newest first, and a preview of the selected one.
//

import ClipboardHistory
import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var clipboard: ClipboardViewModel
    let query: String
    let listWidth: CGFloat
    /// `nil` when previews are turned off in Settings.
    let previewWidth: CGFloat?
    var cornerRadius: CGFloat
    var padding: CGFloat

    private var items: [ClipItem] { clipboard.filteredItems(matching: query) }
    private var selected: ClipItem? { items[safe: clipboard.selectedIndex] }

    var body: some View {
        if clipboard.items.isEmpty {
            Text("Copy something and it shows up here")
                .foregroundColor(.secondary)
                .italic()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 0) {
                list
                    .frame(width: previewWidth == nil ? nil : listWidth)
                    .frame(maxWidth: previewWidth == nil ? .infinity : nil)
                if let previewWidth {
                    Divider()
                    preview
                        .frame(width: previewWidth)
                }
            }
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        row(item, isSelected: index == clipboard.selectedIndex)
                            .onTapGesture { clipboard.selectedIndex = index }
                    }
                    if items.isEmpty {
                        Text("No matches")
                            .foregroundColor(.secondary)
                            .italic()
                            .padding()
                    }
                }
            }
            .scrollIndicators(.never)
            .contentMargins(padding, for: .scrollContent)
            .onChange(of: clipboard.selectedIndex) { _, index in
                if let item = items[safe: index] { proxy.scrollTo(item.id) }
            }
        }
    }

    private func row(_ item: ClipItem, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            icon(for: item)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.isEmpty ? "(whitespace)" : item.title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(subtitle(for: item))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: WindowRowView.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func icon(for item: ClipItem) -> some View {
        switch item.kind {
        case .text:
            Image(systemName: "text.alignleft")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
        case .image:
            if let thumbnail = clipboard.thumbnail(for: item) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: "photo").font(.system(size: 18)).foregroundStyle(.secondary)
            }
        case .files:
            if let first = item.fileURLs?.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: first.path))
                    .resizable()
                    .scaledToFit()
            }
        }
    }

    private func subtitle(for item: ClipItem) -> String {
        let age = item.date.formatted(.relative(presentation: .named))
        return [item.sourceApp, age].compactMap { $0 }.joined(separator: " · ")
    }

    @ViewBuilder
    private var preview: some View {
        if let item = selected {
            switch item.kind {
            case .text:
                ScrollView {
                    Text(item.text ?? "")
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding()
                }
            case .image:
                if let image = clipboard.image(for: item) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .files:
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(item.fileURLs ?? [], id: \.self) { url in
                            HStack(spacing: 8) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(url.lastPathComponent).lineLimit(1)
                                    Text(url.deletingLastPathComponent().path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding()
                }
            }
        } else {
            Text("No preview")
                .foregroundColor(.secondary)
                .italic()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
