//
//  Mouse_ControllerApp.swift
//  Mouse Controller
//
//  Created by Lian on 25.12.25.
//

import SwiftUI

@main
struct Mouse_Controller: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .defaultSize(width: 520, height: 420)
    }
}
