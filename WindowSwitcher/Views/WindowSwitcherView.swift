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
    
    // MARK: - Dimensions
    private var panelWidth: CGFloat { CGFloat(vm.panelWidth) }
    private var panelHeight: CGFloat { CGFloat(vm.panelHeight) }
    private var previewRatio: CGFloat { CGFloat(vm.previewWidthPercentage) }
    
    private var previewWidth: CGFloat {
        panelWidth * previewRatio
    }
    
    private var listWidth: CGFloat {
        vm.isPreviewEnabled ? (panelWidth - previewWidth) : panelWidth
    }
    
    let visibleLines: Int = 6
    @State private var visibleFrom: Int = 0
    @State private var visibleTo: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    header
                    windowList
                }
                .frame(width: listWidth)

                if vm.isPreviewEnabled {
                    Divider()
                    previewPanel
                        .frame(width: previewWidth)
                }
            }
            .onAppear() {
                visibleTo = visibleLines - 1
            }
            .background(VisualEffectBlur(darkeningOpacity: 0.25))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    topTrailingRadius: 10
                )
            )
            .foregroundStyle(.primary)
            .frame(width: panelWidth, height: panelHeight)

            footer
                .clipShape(
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: 10,
                        bottomTrailingRadius: 10
                    )
                )
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - parts
    var header: some View {
        VStack(spacing: 0) {
            KeyHandlingTextField(
                text: $vm.filterText,
                isFocused: $isFocused,
                onEnter: { vm.handleEnter() },
                onEscape: { vm.handleEscape() },
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
                            }
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: vm.selectedIndex) { _, newIndex in
                let count = vm.displayedWindows.count
                
                if newIndex > visibleTo {
                    // Selection moved past bottom → scroll down
                    proxy.scrollTo(newIndex, anchor: .bottom)
                    visibleFrom += 1
                    visibleTo += 1
                } else if newIndex < visibleFrom {
                    // Selection moved past top → scroll up
                    proxy.scrollTo(newIndex, anchor: .top)
                    visibleFrom -= 1
                    visibleTo -= 1
                }
                
                if newIndex == 0 {
                    visibleFrom = 0
                    visibleTo = visibleLines - 1
                } else if newIndex == count - 1 {
                    visibleFrom = count - visibleLines
                    visibleTo = count - 1
                }
            }
        }
    }

    var previewPanel: some View {
        ZStack {
            VisualEffectBlur(darkeningOpacity: 0.35)

            VStack(alignment: .leading, spacing: 0) {
                if let img = vm.previewImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(
                            cornerRadius: 3
                        ))
                        .shadow(color: Color.black.opacity(0.5), radius: 15, x: 0, y: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

                if vm.isDebugMode && vm.displayedWindows.indices.contains(vm.selectedIndex) {
                    let w = vm.displayedWindows[vm.selectedIndex]
                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text("Title: \(w.title)")
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text("App: \(w.app)")
                            Text("Space: \(w.space)")
                            Text("Image created at: \(w.cachedSnapshot?.createdAt.formatted(date: .omitted, time: .standard) ?? "0")")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // Expands to fill 50%
                        
                        VStack(alignment: .leading) {
                            Text("ID (Yabai): \(w.id)")
                            Text("PID: \(w.pid)")
                            Text("Bundle ID: \(w.bundleID ?? "0")")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading) // Expands to fill the other 50%
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
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
    }
}
