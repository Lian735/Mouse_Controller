//
//  AppDelegate.swift
//  Mouse Controller
//
//  Created by Lian on 25.12.25.
//


import Cocoa
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        Accessibility.requestPromptIfNeeded()
        ControllerMouseService.shared.start()
        GameModeMonitor.shared.start()
        _ = ControllerInputManager.shared
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if let image = NSImage(named: "MouseController") {
                // Ensure proper size and template rendering for the menu bar
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
                button.imageScaling = .scaleProportionallyDown
                #if DEBUG
                print("[StatusItem] Loaded MouseController asset for status bar icon")
                #endif
            } else {
                // Fallback to SF Symbol if asset is missing
                let fallback = NSImage(systemSymbolName: "gamecontroller", accessibilityDescription: "Controller Mouse")
                fallback?.size = NSSize(width: 18, height: 18)
                fallback?.isTemplate = true
                button.image = fallback
                button.imageScaling = .scaleProportionallyDown
                #if DEBUG
                print("[StatusItem] Failed to load MouseController asset, using fallback symbol")
                #endif
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 320, height: 260)
        popover.contentViewController = NSHostingController(rootView: StatusMenuView())
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
