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

            HStack {
                Text("Controller:")
                Spacer()
                Text(service.controllerStatusText())
                    .foregroundStyle(.secondary)
            }
            if !Accessibility.isTrusted {
                HStack {
                    Text("Permissions:")
                    Spacer()
                    Text("⚠️ Missing")
                        .modifier(AccessibilityStatusStyle(isTrusted: Accessibility.isTrusted))
                }
                Button("Request Accessibility Permission") {
                    Accessibility.requestPromptIfNeeded()
                }
            }

            Divider()

            HStack {
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
                .buttonStyle(.glassProminent)
                .tint(.gray.opacity(0.5))
                
                Spacer()
                
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.glassProminent)
                    .tint(.red.opacity(0.5))
            }
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
