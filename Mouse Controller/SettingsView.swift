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
    case controls
    case shortcuts
    case advanced
}

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var store = ShortcutStore.shared
    @StateObject private var mouseService = ControllerMouseService.shared
    @State private var isCapturingButton: Bool = false
    @State private var selection: SettingsTab = .controls
    @State private var showDeleteAllConfirm: Bool = false

    private var leftStickMapped: Bool { store.hasStickBindings(.left) }
    private var rightStickMapped: Bool { store.hasStickBindings(.right) }
    private var pointerStickMapped: Bool {
        settings.useRightStickForPointer ? rightStickMapped : leftStickMapped
    }
    private var scrollStickMapped: Bool {
        settings.useRightStickForPointer ? leftStickMapped : rightStickMapped
    }

    var body: some View {
        TabView(selection: $selection) {
            controlsTab
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(SettingsTab.controls)

            shortcutsTab
                .tabItem {
                    Label("Shortcuts", systemImage: "command")
                }
                .tag(SettingsTab.shortcuts)

//            advancedTab
//                .tabItem {
//                    Label("Advanced", systemImage: "slider.horizontal.3")
//                }
//                .tag(SettingsTab.advanced)
        }
        .tabViewStyle(.automatic)
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

    private var controlsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsCard3 {
                    HStack(alignment: .center, spacing: 12) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mouse Controller")
                                .font(.headline)
                        }

                        Spacer()
                        
                        Toggle(isOn: $settings.enabled) {
                            EmptyView()
                        }
                        .toggleStyle(.switch)
                        .accessibilityLabel("Enable Mouse Controller")
                    }
                    Divider()
                    LabeledContent("Controller") {
                        Text(mouseService.controllerName.capitalized)
                            .foregroundStyle(.secondary)
                    }
                }

                SettingsCard(title: "Pointer") {
                    Toggle("Use right stick for pointer", isOn: $settings.useRightStickForPointer)
                    SettingSlider(title: "Cursor speed", value: $settings.cursorSpeed, range: 2...40, step: 1, valueText: "\(Int(settings.cursorSpeed))")
                        .disabled(pointerStickMapped)
                    SettingSlider(title: "Pointer acceleration", value: $settings.pointerAcceleration, range: 0.1...3.0, step: 0.1, valueText: String(format: "%.1fx", settings.pointerAcceleration))
                        .disabled(pointerStickMapped)
                    SettingSlider(title: "Deadzone", value: $settings.deadzone, range: 0.0...0.4, step: 0.01, valueText: String(format: "%.2f", settings.deadzone))
                        .disabled(pointerStickMapped)
                    Toggle("Invert vertical", isOn: $settings.invertY)
                        .disabled(pointerStickMapped)
                    Toggle("Invert horizontal", isOn: $settings.invertX)
                        .disabled(pointerStickMapped)
                    if pointerStickMapped {
                        SettingsHint(text: pointerStickHint)
                    }
                }

                SettingsCard(title: "Scrolling") {
                    SettingSlider(title: "Scroll speed", value: $settings.scrollSpeed, range: 2...60, step: 1, valueText: "\(Int(settings.scrollSpeed))")
                        .disabled(scrollStickMapped)
                    Toggle("Horizontal scroll", isOn: $settings.horizontalScrollEnabled)
                        .disabled(scrollStickMapped)
                    Toggle("Invert vertical scroll", isOn: $settings.invertScrollY)
                        .disabled(scrollStickMapped)
                    Toggle("Invert horizontal scroll", isOn: $settings.invertScrollX)
                        .disabled(scrollStickMapped)
                    if scrollStickMapped {
                        SettingsHint(text: scrollStickHint)
                    }
                }
            }
            .padding(24)
        }
    }

    private var pointerStickHint: String {
        settings.useRightStickForPointer
            ? "Right stick shortcuts are active. Remove Joystick Right bindings to restore pointer controls."
            : "Left stick shortcuts are active. Remove Joystick Left bindings to restore pointer controls."
    }

    private var scrollStickHint: String {
        settings.useRightStickForPointer
            ? "Left stick shortcuts are active. Remove Joystick Left bindings to restore scrolling."
            : "Right stick shortcuts are active. Remove Joystick Right bindings to restore scrolling."
    }

    private var shortcutsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsCard2 {
                    let buttons = store.bindings.keys.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                        LazyVStack(spacing: 12) {
                            if isCapturingButton {
                                // Listening panel with Cancel action
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Listening for controller input…")
                                    Spacer()
                                    Button("Cancel") {
                                        isCapturingButton = false
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            } else {
                                // Add panel as a button
                                HStack(spacing: 12) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 28, weight: .semibold))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Add Shortcut")
                                            .font(.headline)
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .onTapGesture { isCapturingButton = true }
                                .glassEffect(
                                    .regular,
                                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                                )
                            }
                            
                            Divider()
                            if buttons.isEmpty {
                                ContentUnavailableView("No inputs yet", systemImage: "gamecontroller", description: Text("Add a controller input to start assigning shortcuts."))
                            } else {
                            
                                ForEach(buttons, id: \.self) { btn in
                                    ShortcutRow(button: btn)
                                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                }
                                
                                Button(role: .destructive) {
                                    showDeleteAllConfirm = true
                                } label: {
                                    Label("Delete All Shortcuts", systemImage: "trash")
                                }
                                .buttonStyle(.glassProminent)
                                .tint(.red.opacity(0.5))
                                .confirmationDialog(
                                    "Delete All Shortcuts?",
                                    isPresented: $showDeleteAllConfirm,
                                    titleVisibility: .visible
                                ) {
                                    Button("Delete All Shortcuts", role: .destructive) {
                                        store.reset()
                                    }
                                    Button("Cancel", role: .cancel) { }
                                } message: {
                                    Text("This will remove every configured shortcut. This action cannot be undone.")
                                }
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var advancedTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeader(title: "Advanced", subtitle: "Experimental controls and fine-tuning")

                SettingsCard(title: "Experimental") {
                    Toggle("Enable experimental cursor mode", isOn: $settings.experimentalTeleportEnabled)
                    SettingSlider(title: "Teleport radius", value: $settings.experimentalTeleportRadius, range: 80...800, step: 10, valueText: "\(Int(settings.experimentalTeleportRadius)) px")
                        .disabled(!settings.experimentalTeleportEnabled)
                    Text("Move the stick to jump the cursor within the radius. A quick release recenters the radius on the last cursor position.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}

private struct SettingsCard2<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsCard3<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
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
                Image(systemName: "ellipsis")
                    .font(.title3)
            }
        }
        .padding(12)
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
        store.removeButton(button)
    }
}
