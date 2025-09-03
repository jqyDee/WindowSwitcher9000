//
//  SettingsView.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 02.09.25.
//

import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        HStack {
            Text("Configure Hotkey")
                .padding()
            KeyboardShortcuts.Recorder(for: .openHotkeyWindow)
                .onSubmit {
                    print("settings : new hotkey")
                }
                .padding()
        }
    }
}

extension KeyboardShortcuts.Name {
    static let openHotkeyWindow = Self("openHotkeyWindow")
}

#Preview {
    SettingsView()
}
