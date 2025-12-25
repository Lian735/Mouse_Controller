//
//  SettingsView.swift
//  Mouse Controller
//
//  Created by Lian on 25.12.25.
//


import SwiftUI
import ApplicationServices

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var store = ShortcutStore.shared
    @State private var isCapturingButton: Bool = false

    var body: some View {
        TabView {
            Form {
                Section {
                    Toggle("Enabled", isOn: $settings.enabled)
                }

                Section("Pointer") {
                    Slider(value: $settings.cursorSpeed, in: 2...40, step: 1) {
                        Text("Cursor speed")
                    }
                    Text("Cursor speed: \(Int(settings.cursorSpeed))")
                        .foregroundStyle(.secondary)
                }

                Section("Scrolling") {
                    Slider(value: $settings.scrollSpeed, in: 2...60, step: 1) {
                        Text("Scroll speed")
                    }
                    Text("Scroll speed: \(Int(settings.scrollSpeed))")
                        .foregroundStyle(.secondary)
                    Toggle("Horizontal scroll", isOn: $settings.horizontalScrollEnabled)
                }

                Section("Shortcuts") {
                    if isCapturingButton {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Press a button on your controller to add it...")
                            Spacer()
                            Button("Cancel") { isCapturingButton = false }
                        }
                    }
                    let buttons = store.bindings.keys.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    if buttons.isEmpty {
                        Text("No controller buttons detected yet. Press any button on your controller to have it appear here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(buttons, id: \.self) { btn in
                            ShortcutRow(title: btn.name, button: btn)
                        }
                    }
                    Button(role: .destructive) {
                        store.reset()
                    } label: {
                        Text("Reset All Shortcuts")
                    }
                }
            }
            .padding(16)
            .tabItem {
                Label("General", systemImage: "slider.horizontal.3")
            }

            Form {
                Section("Mouse movement") {
                    Toggle("Invert vertical", isOn: $settings.invertY)
                    Toggle("Invert horizontal", isOn: $settings.invertX)
                    Slider(value: $settings.pointerAcceleration, in: 0.1...3.0, step: 0.1) {
                        Text("Pointer acceleration")
                    }
                    Text(String(format: "Pointer acceleration: %.1fx", settings.pointerAcceleration))
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.deadzone, in: 0.0...0.4, step: 0.01) {
                        Text("Deadzone")
                    }
                    Text(String(format: "Deadzone: %.2f", settings.deadzone))
                        .foregroundStyle(.secondary)
                }

                Section("Scrolling") {
                    Toggle("Invert vertical scroll", isOn: $settings.invertScrollY)
                    Toggle("Invert horizontal scroll", isOn: $settings.invertScrollX)
                }
            }
            .padding(16)
            .tabItem {
                Label("Advanced", systemImage: "gearshape")
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCapturingButton = true
                } label: {
                    Label("Add Button", systemImage: "plus")
                }
                .disabled(isCapturingButton)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ControllerButtonDetected"))) { note in
            guard isCapturingButton,
                  let name = note.userInfo?["name"] as? String,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            let btn = ControllerButton(name)
            store.ensureButton(btn)
            isCapturingButton = false
        }
    }
}

struct ShortcutRow: View {
    @StateObject private var store = ShortcutStore.shared
    let title: String
    let button: ControllerButton
    @State private var tempShortcut: Shortcut? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
            Spacer()
            // Shows currently assigned action in a compact form
            Text(currentActionDescription)
                .foregroundStyle(.secondary)
            ShortcutRecorderView(recorded: Binding(
                get: { tempShortcut ?? store.shortcut(for: button) },
                set: { newValue in
                    tempShortcut = newValue
                    store.set(newValue, for: button)
                })
            )
            Menu {
                Button("Clear") { store.set(nil, for: button) }
                Button("Reset to Default") { resetToDefault() }
                Divider()
                Button(role: .destructive) {
                    removeButton()
                } label: {
                    Text("Remove from List")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var currentActionDescription: String {
        if let s = store.shortcut(for: button) {
            return s.description
        } else {
            return "—"
        }
    }

    private func resetToDefault() {
        // Define your defaults here. For now, just clear.
        store.set(nil, for: button)
    }

    private func removeButton() {
        // Removing means clearing the binding so it disappears from the dynamic list when no shortcut is associated.
        store.set(nil, for: button)
        // Also explicitly remove the key from the bindings dictionary if present.
        store.bindings.removeValue(forKey: button)
    }
}
