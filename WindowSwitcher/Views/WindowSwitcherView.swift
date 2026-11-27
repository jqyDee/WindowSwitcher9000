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
    private let searchBarHeight: CGFloat = 56
    private let footerHeight: CGFloat = 30
    private let listPadding: CGFloat = 8
    private let cardCornerRadius: CGFloat = 26
    /// Liquid Glass tinted darker than the system default; raise the opacity for darker glass.
    private let glass: Glass = .regular.tint(.black.opacity(0.35))
    private let rowHeight: CGFloat = WindowRowView.height
    
    private var previewWidth: CGFloat {
        panelWidth * previewRatio
    }
    
    private var listWidth: CGFloat {
        vm.isPreviewEnabled ? (panelWidth - previewWidth) : panelWidth
    }
    
    // Calculate visible lines based on the panel height
    private var visibleLines: Int {
        let availableHeight = panelHeight - footerHeight - listPadding * 2
        return Int(floor(availableHeight / rowHeight))
    }
    @State private var visibleFrom: Int = 0
    @State private var visibleTo: Int = 0
    /// On-screen width of the fitted preview image, used to scale the window corner radius.
    @State private var previewDisplayWidth: CGFloat = 0
    /// Approximate corner radius of a macOS 26+ window at full size (points).
    private let windowCornerRadius: CGFloat = 24

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                searchBar
                    .frame(width: panelWidth, height: searchBarHeight)
                    .glassEffect(glass, in: Capsule())

                resultsCard
                    .frame(width: panelWidth, height: panelHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                    .glassEffect(glass, in: RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            }
        }
        .foregroundStyle(.primary)
        .padding(12) // room for the glass edge highlights and shadow
        .onAppear {
            visibleTo = visibleLines - 1
        }
        .onChange(of: vm.panelHeight) {
            visibleTo = visibleFrom + visibleLines - 1
        }
    }

    var resultsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if vm.isMathMode {
                    CalculatorHistoryView(
                        calculator: vm.calculator,
                        cornerRadius: cardCornerRadius - listPadding,
                        padding: listPadding
                    )
                } else {
                    windowList
                        .frame(width: listWidth)

                    if vm.isPreviewEnabled {
                        Divider()
                        previewPanel
                            .frame(width: previewWidth)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            footer
        }
    }

    // MARK: - parts
    var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: vm.isMathMode ? "function" : "magnifyingglass")
                .frame(width: 24)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)

            KeyHandlingTextField(
                text: $vm.filterText,
                isFocused: $isFocused,
                onEnter: { vm.handleEnter() },
                onEscape: { vm.handleEscape() },
                onTab: { vm.moveSelectionForward() },
                onShiftTab: { vm.moveSelectionBackward() },
                onSettings: {
                    FloatingPanelHandler.shared.closePanel()
                    MenuBarHandler.shared.openSettings()
                },
                onCommandEnter: { vm.handleCommandEnter() },
                onBackspaceWhenEmpty: { vm.handleBackspaceOnEmpty() },
                onCommandBackspace: { vm.handleCommandBackspace() },
                placeholder: vm.isMathMode ? "Calculate ..." : "Find the Program in your mess ..."
            )
            .frame(height: 30)

            if case .math(let expression) = vm.inputMode {
                CalculatorResultLabel(calculator: vm.calculator, expression: expression)
            }
        }
        .padding(.horizontal, 20)
    }

    var windowList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.displayedWindows.indices, id: \.self) { idx in
                        let window = vm.displayedWindows[idx]
                        WindowRowView(
                            window: window,
                            isSelected: idx == vm.selectedIndex,
                            // concentric with the card: outer radius minus the gap to its edge
                            cornerRadius: cardCornerRadius - listPadding
                        )
                            .id(idx)
                            .onTapGesture {
                                vm.selectedIndex = idx
                            }
                    }
                }
            }
            .scrollIndicators(.never)
            // margins, not padding: scrollTo keeps rows inside them, so the gap survives scrolling
            .contentMargins(listPadding, for: .scrollContent)
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
            VStack(alignment: .leading, spacing: 0) {
                if let img = vm.previewImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { previewDisplayWidth = $0 }
                        // The capture is a plain rectangle, so round it like a real window,
                        // scaled down by the same factor as the image (it's captured in points).
                        .clipShape(RoundedRectangle(
                            cornerRadius: img.size.width > 0 ? windowCornerRadius * previewDisplayWidth / img.size.width : 0,
                            style: .continuous
                        ))
                        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
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
            .padding(.horizontal, 18)
            .frame(height: footerHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
