//
//  LoginItemManager.swift
//  Mouse Controller
//
//  Created by Lian on 25.12.25.
//

import Foundation
import ServiceManagement

enum LoginItemManager {
    static func isEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update login item: \(error.localizedDescription)")
        }
    }
}
