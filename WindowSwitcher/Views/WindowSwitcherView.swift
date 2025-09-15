//
//  WindowSwitcherView.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//


import SwiftUI
import AppKit

struct WindowSwitcherView: View {
    @StateObject var vm = WindowSwitcherViewModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    header
                    windowList
                }
                .frame(width: vm.isPreviewEnabled ? 400 : 900)

                if vm.isPreviewEnabled {
                    Divider()
                    previewPanel
                        .frame(width: 500)
                }
            }
            .background(VisualEffectBlur(darkeningOpacity: 0.25))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    topTrailingRadius: 10
                )
            )
            .foregroundStyle(.primary)
            .frame(width: 900, height: 400)

            footer
                .frame(maxWidth: .infinity)
        }
        .onAppear {
            isFocused = true
            Task {
                await vm.refreshWindows()
                vm.clampSelectedIndex()
                vm.requestSnapshotForSelected()
            }
        }
    }

    // MARK: - parts
    var header: some View {
        VStack(spacing: 0) {
            KeyHandlingTextField(
                text: $vm.filterText,
                isFocused: $isFocused,
                onEnter: { vm.handleEnter() },
                onEscape: { handleEscape() },
                onTab: { vm.moveSelectionForward() },
                onShiftTab: { vm.moveSelectionBackward() }
            )
            .frame(height: 30)
            .font(.title)
            .textFieldStyle(.plain)
            .padding(.bottom)

            Divider().frame(height: 0.08)
        }
        .padding()
    }

    var windowList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.displayedWindows.indices, id: \.self) { idx in
                        let window = vm.displayedWindows[idx]
                        WindowRowView(window: window, isSelected: idx == vm.selectedIndex)
                            .id(idx)
                            .onTapGesture {
                                vm.selectedIndex = idx
                                vm.requestSnapshotForSelected()
                                vm.focusWindow(window)
                            }
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: vm.selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
                vm.requestSnapshotForSelected()
            }
        }
    }

    var previewPanel: some View {
        ZStack {
            VisualEffectBlur(darkeningOpacity: 0.35)
                // .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                if let img = vm.previewImage {
                    Image(nsImage: img).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("No preview")
                        .foregroundColor(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if vm.hasScreenCaptureAccess == false {
                        Text("⚠️ Enable Screen Recording in System Settings → Privacy & Security")
                            .foregroundColor(.secondary)
                            .italic()
                            .padding()
                    }
                }

                if vm.displayedWindows.indices.contains(vm.selectedIndex) {
                    let w = vm.displayedWindows[vm.selectedIndex]
                    VStack(alignment: .leading) {
                        Text("Title: \(w.title.isEmpty ? "(Untitled)" : w.title)")
                        Text("App: \(w.app)")
                        Text("Space: \(w.space)")
                        Text("PID: \(w.pid)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding([.vertical, .trailing], 4)
                }
            }
            .padding()
        }
    }

    var footer: some View {
        VStack(spacing: 0) {
            Divider().frame(height: 0.08)
            HStack {
                Button(action: { if let url = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ") { NSWorkspace.shared.open(url) } }) {
                    Image(systemName: "rectangle.3.offgrid").resizable().frame(width: 12, height: 12).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                if let commands = vm.footerCommands {
                    Text(commands).font(.subheadline).foregroundColor(.secondary).lineLimit(1).truncationMode(.tail)
                }

                Spacer()
                Text("WindowSwitcher9000").font(.subheadline).foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .frame(height: 30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(VisualEffectBlur(darkeningOpacity: 0.4))
        .clipShape(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 10,
                bottomTrailingRadius: 10
            )
        )
    }
    
    private func handleEscape() {
        if !vm.filterText.isEmpty {
            vm.filterText = ""
        } else {
            FloatingPanelHandler.shared.closePanel()
        }
    }
}
