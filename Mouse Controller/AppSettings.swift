//
//  AppSettings.swift
//  Mouse Controller
//
//  Created by Lian on 25.12.25.
//


import Foundation
import Combine
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private init() { load() }

    @Published var enabled: Bool = true { didSet { save() } }
    @Published var cursorSpeed: Double = 18 { didSet { save() } }
    @Published var pointerAcceleration: Double = 1.0 { didSet { save() } }
    @Published var scrollSpeed: Double = 24 { didSet { save() } }
    @Published var invertScrollY: Bool = false { didSet { save() } }
    @Published var invertScrollX: Bool = false { didSet { save() } }
    @Published var deadzone: Double = 0.15 { didSet { save() } }
    @Published var invertY: Bool = false { didSet { save() } }
    @Published var invertX: Bool = false { didSet { save() } }
    @Published var horizontalScrollEnabled: Bool = true { didSet { save() } }
    @Published var swapSticks: Bool = false { didSet { save() } }
    @Published var experimentalTeleportEnabled: Bool = false { didSet { save() } }
    @Published var experimentalTeleportRadius: Double = 260 { didSet { save() } }
    @Published var autoDisableInGameMode: Bool = true { didSet { save() } }
    @Published var launchAtLogin: Bool = LoginItemManager.isEnabled() { didSet { save(); LoginItemManager.setEnabled(launchAtLogin) } }

    private let d = UserDefaults.standard
    private let k = "ControllerMouseSettings"

    private func load() {
        guard let obj = d.dictionary(forKey: k) else { return }
        enabled = obj["enabled"] as? Bool ?? enabled
        cursorSpeed = obj["cursorSpeed"] as? Double ?? cursorSpeed
        pointerAcceleration = obj["pointerAcceleration"] as? Double ?? pointerAcceleration
        scrollSpeed = obj["scrollSpeed"] as? Double ?? scrollSpeed
        invertScrollY = obj["invertScrollY"] as? Bool ?? invertScrollY
        invertScrollX = obj["invertScrollX"] as? Bool ?? invertScrollX
        deadzone = obj["deadzone"] as? Double ?? deadzone
        invertY = obj["invertY"] as? Bool ?? invertY
        invertX = obj["invertX"] as? Bool ?? invertX
        horizontalScrollEnabled = obj["horizontalScrollEnabled"] as? Bool ?? horizontalScrollEnabled
        swapSticks = obj["swapSticks"] as? Bool ?? swapSticks
        experimentalTeleportEnabled = obj["experimentalTeleportEnabled"] as? Bool ?? experimentalTeleportEnabled
        experimentalTeleportRadius = obj["experimentalTeleportRadius"] as? Double ?? experimentalTeleportRadius
        autoDisableInGameMode = obj["autoDisableInGameMode"] as? Bool ?? autoDisableInGameMode
        if let launchSetting = obj["launchAtLogin"] as? Bool {
            launchAtLogin = launchSetting
        } else {
            launchAtLogin = LoginItemManager.isEnabled()
        }
    }

    private func save() {
        d.set([
            "enabled": enabled,
            "cursorSpeed": cursorSpeed,
            "pointerAcceleration": pointerAcceleration,
            "scrollSpeed": scrollSpeed,
            "invertScrollY": invertScrollY,
            "invertScrollX": invertScrollX,
            "deadzone": deadzone,
            "invertY": invertY,
            "invertX": invertX,
            "horizontalScrollEnabled": horizontalScrollEnabled,
            "swapSticks": swapSticks,
            "experimentalTeleportEnabled": experimentalTeleportEnabled,
            "experimentalTeleportRadius": experimentalTeleportRadius,
            "autoDisableInGameMode": autoDisableInGameMode,
            "launchAtLogin": launchAtLogin
        ], forKey: k)
    }
}
