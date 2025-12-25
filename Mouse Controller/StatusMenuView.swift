//
//  StatusMenuView.swift
//  Mouse Controller
//
//  Created by Lian on 25.12.25.
//


import SwiftUI
import Combine

struct StatusMenuView: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var service = ControllerMouseService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enabled", isOn: $settings.enabled)

            HStack {
                Text("Controller:")
                Spacer()
                Text(service.controllerName)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Accessibility:")
                Spacer()
                Text(Accessibility.isTrusted ? "OK" : "Missing")
                    .modifier(AccessibilityStatusStyle(isTrusted: Accessibility.isTrusted))
            }

            Divider()

            Button("Request Accessibility Permission") {
                Accessibility.requestPromptIfNeeded()
            }

            Group {
                if #available(macOS 14.0, *) {
                    SettingsLink {
                        Label("Open Settings", systemImage: "gear")
                    }
                } else {
                    Button("Open Settings") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                }
            }

            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding(14)
        .onChange(of: settings.enabled) { _, newValue in
            service.setEnabled(newValue)
        }
    }
}

private struct AccessibilityStatusStyle: ViewModifier {
    let isTrusted: Bool

    func body(content: Content) -> some View {
        if isTrusted {
            content.foregroundStyle(.secondary)
        } else {
            content.foregroundColor(.red)
        }
    }
}

