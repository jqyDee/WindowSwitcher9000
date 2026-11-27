//
//  WindowRowView.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//


// Views/WindowRowView.swift
import SwiftUI

struct WindowRowView: View {
    static let height: CGFloat = 52
    
    let window: Window
    let isSelected: Bool
    /// Radius of the selection highlight; the list passes one concentric with the card's corners.
    var cornerRadius: CGFloat = 14

    var body: some View {
        HStack(spacing: 10) {
            if let icon = window.appIcon {
                Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit).frame(width: 32, height: 32)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(window.title.isEmpty ? "(Untitled)" : window.title).font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: false)
                Text(window.app).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: Self.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.12) : .clear)
        )
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}
