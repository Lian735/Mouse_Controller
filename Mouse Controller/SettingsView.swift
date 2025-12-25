//
//  SettingsView.swift
//  Mouse Controller
//
//  Created by Lian on 25.12.25.
//

import SwiftUI
import Combine
import Foundation

private enum SettingsTab: Hashable {
    case general
    case controls
    case shortcuts
}

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var store = ShortcutStore.shared
    @StateObject private var mouseService = ControllerMouseService.shared
    @State private var isCapturingButton: Bool = false
    @State private var selection: SettingsTab = .general

    private var leftStickMapped: Bool { store.hasStickBindings(.left) }
    private var rightStickMapped: Bool { store.hasStickBindings(.right) }

    var body: some View {
        TabView(selection: $selection) {
            generalTab
                .tabItem {
                    Label("General", systemImage: "sparkles")
                }
                .tag(SettingsTab.general)

            controlsTab
                .tabItem {
                    Label("Controls", systemImage: "gamecontroller")
                }
                .tag(SettingsTab.controls)

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }
                .tag(SettingsTab.shortcuts)
        }
        .tabViewStyle(.sidebarAdaptable)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if selection == .shortcuts {
                    Button {
                        isCapturingButton = true
                    } label: {
                        Label("Add Input", systemImage: "plus")
                    }
                    .disabled(isCapturingButton)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ControllerButtonDetected"))) { note in
            guard isCapturingButton,
                  let name = note.userInfo?["name"] as? String,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            if let stick = JoystickBinding.stick(for: name) {
                store.ensureButtons(JoystickBinding.buttons(for: stick))
            } else {
                let btn = ControllerButton(name)
                store.ensureButton(btn)
            }
            isCapturingButton = false
        }
    }

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeader(title: "Mouse Controller", subtitle: "Fine-tune how your controller drives your cursor")

                SettingsCard(title: "Status", subtitle: "Quick access to the essentials") {
                    Toggle("Enabled", isOn: $settings.enabled)
                    Divider()
                    LabeledContent("Controller") {
                        Text(mouseService.controllerName.capitalized)
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsCard(title: "Highlights", subtitle: "Your most-used settings") {
                    SettingSlider(title: "Cursor speed", value: $settings.cursorSpeed, range: 2...40, step: 1, valueText: "\(Int(settings.cursorSpeed))")
                        .disabled(leftStickMapped)
                    if leftStickMapped {
                        SettingsHint(text: "Left stick is assigned to shortcuts. Remove Joystick Left bindings to re-enable cursor controls.")
                    }
                    Divider()
                    SettingSlider(title: "Scroll speed", value: $settings.scrollSpeed, range: 2...60, step: 1, valueText: "\(Int(settings.scrollSpeed))")
                        .disabled(rightStickMapped)
                    Toggle("Horizontal scroll", isOn: $settings.horizontalScrollEnabled)
                        .disabled(rightStickMapped)
                    if rightStickMapped {
                        SettingsHint(text: "Right stick is assigned to shortcuts. Remove Joystick Right bindings to re-enable scrolling.")
                    }
                }
            }
            .padding(24)
        }
    }

    private var controlsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeader(title: "Controls", subtitle: "Precision adjustments for pointer and scrolling")

                SettingsCard(title: "Pointer", subtitle: "Movement, acceleration, and inversion") {
                    SettingSlider(title: "Cursor speed", value: $settings.cursorSpeed, range: 2...40, step: 1, valueText: "\(Int(settings.cursorSpeed))")
                        .disabled(leftStickMapped)
                    SettingSlider(title: "Pointer acceleration", value: $settings.pointerAcceleration, range: 0.1...3.0, step: 0.1, valueText: String(format: "%.1fx", settings.pointerAcceleration))
                        .disabled(leftStickMapped)
                    SettingSlider(title: "Deadzone", value: $settings.deadzone, range: 0.0...0.4, step: 0.01, valueText: String(format: "%.2f", settings.deadzone))
                        .disabled(leftStickMapped)
                    Toggle("Invert vertical", isOn: $settings.invertY)
                        .disabled(leftStickMapped)
                    Toggle("Invert horizontal", isOn: $settings.invertX)
                        .disabled(leftStickMapped)
                    if leftStickMapped {
                        SettingsHint(text: "Left stick shortcuts are active. Remove Joystick Left bindings to restore pointer controls.")
                    }
                }

                SettingsCard(title: "Scrolling", subtitle: "Comfortable and consistent scrolling") {
                    SettingSlider(title: "Scroll speed", value: $settings.scrollSpeed, range: 2...60, step: 1, valueText: "\(Int(settings.scrollSpeed))")
                        .disabled(rightStickMapped)
                    Toggle("Horizontal scroll", isOn: $settings.horizontalScrollEnabled)
                        .disabled(rightStickMapped)
                    Toggle("Invert vertical scroll", isOn: $settings.invertScrollY)
                        .disabled(rightStickMapped)
                    Toggle("Invert horizontal scroll", isOn: $settings.invertScrollX)
                        .disabled(rightStickMapped)
                    if rightStickMapped {
                        SettingsHint(text: "Right stick shortcuts are active. Remove Joystick Right bindings to restore scrolling.")
                    }
                }
            }
            .padding(24)
        }
    }

    private var shortcutsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeader(title: "Shortcuts", subtitle: "Map controller inputs to keyboard or mouse actions")

                SettingsCard(title: "Record inputs", subtitle: "Press a button or tilt a stick to add it") {
                    if isCapturingButton {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Listening for controller input…")
                            Spacer()
                            Button("Cancel") { isCapturingButton = false }
                        }
                    } else {
                        Text("Click \"Add Input\" in the toolbar, then press a button or move a stick to add it here.")
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsCard(title: "Bindings", subtitle: "Assign shortcuts to each controller input") {
                    let buttons = store.bindings.keys.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                    if buttons.isEmpty {
                        ContentUnavailableView("No inputs yet", systemImage: "gamecontroller", description: Text("Add a controller input to start assigning shortcuts."))
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(buttons, id: \.self) { btn in
                                ShortcutRow(button: btn)
                                if btn != buttons.last { Divider() }
                            }
                        }
                    }
                }

                SettingsCard(title: "Reset", subtitle: "Clear all shortcut assignments") {
                    Button(role: .destructive) {
                        store.reset()
                    } label: {
                        Label("Reset All Shortcuts", systemImage: "trash")
                    }
                }
            }
            .padding(24)
        }
    }
}

private struct SettingsHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.bold())
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct SettingsHint: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

private struct SettingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(valueText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

struct ShortcutRow: View {
    @StateObject private var store = ShortcutStore.shared
    let button: ControllerButton
    @State private var tempShortcut: Shortcut? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(button.displayName)
                    .font(.headline)
                Text(currentActionDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
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
                    .font(.title3)
            }
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var currentActionDescription: String {
        if let s = store.shortcut(for: button) {
            return s.description
        }
        return "No shortcut assigned"
    }

    private func resetToDefault() {
        store.set(nil, for: button)
    }

    private func removeButton() {
        if JoystickBinding.stick(for: button.name) != nil {
            store.removeStickBindings(for: button)
        } else {
            store.removeButton(button)
        }
    }
}
