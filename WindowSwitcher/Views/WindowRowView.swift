//
//  WindowRowView.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//


// Views/WindowRowView.swift
import SwiftUI

struct WindowRowView: View {
    let window: Window
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            if let icon = window.appIcon {
                Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit).frame(width: 30, height: 30).cornerRadius(4)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(window.title.isEmpty ? "(Untitled)" : window.title).font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: false)
                Text(window.app).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.primary.opacity(0.15) : .clear))
        .buttonStyle(.plain)
    }
}
