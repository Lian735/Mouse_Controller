//
//  ControllerMouseService.swift
//  Mouse Controller
//
//  Created by Lian on 25.12.25.
//


import Foundation
import GameController
import Combine

@MainActor
final class ControllerMouseService: ObservableObject {
    static let shared = ControllerMouseService()
    private init() {}

    @Published private(set) var controllerName: String = "none"

    private var controller: GCController?
    private var timer: Timer?
    private var activity: NSObjectProtocol?

    private var lx: Float = 0
    private var ly: Float = 0
    private var ry: Float = 0
    private var rx: Float = 0

    func start() {
        if #available(macOS 10.15, *) {
            GCController.shouldMonitorBackgroundEvents = true
        }
        // Prevent App Nap from throttling our polling while running in the background
        if activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep], reason: "Controller mouse input")
        }

        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] n in
            guard let c = n.object as? GCController else { return }
            self?.attach(c)
        }
        NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] n in
            guard let c = n.object as? GCController else { return }
            if self?.controller === c { self?.detach() }
        }

        GCController.startWirelessControllerDiscovery(completionHandler: nil)
        if let c = GCController.controllers().first { attach(c) }

        timer?.invalidate()
        let t = Timer(timeInterval: 1.0/120.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func setEnabled(_ enabled: Bool) {
        // hook for UI; tick() liest Settings direkt
    }

    private func attach(_ c: GCController) {
        controller = c
        controllerName = c.vendorName ?? "controller"

        guard let gp = c.extendedGamepad else { return }

        gp.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            self?.lx = x; self?.ly = y
        }
        gp.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            self?.rx = x
            self?.ry = y
        }

        bindButton(gp.buttonA, name: "ButtonA")
        bindButton(gp.buttonB, name: "ButtonB")
        bindButton(gp.buttonX, name: "ButtonX")
        bindButton(gp.buttonY, name: "ButtonY")

        bindButton(gp.leftShoulder, name: "L1")
        bindButton(gp.rightShoulder, name: "R1")

        bindButton(gp.leftTrigger, name: "L2")
        bindButton(gp.rightTrigger, name: "R2")

        bindButton(gp.dpad.up, name: "DPadUp")
        bindButton(gp.dpad.down, name: "DPadDown")
        bindButton(gp.dpad.left, name: "DPadLeft")
        bindButton(gp.dpad.right, name: "DPadRight")

        bindButton(gp.buttonMenu, name: "Menu")
        bindButton(gp.buttonOptions, name: "Options")
        bindButton(gp.buttonHome, name: "Home")

        bindButton(gp.leftThumbstickButton, name: "L3")
        bindButton(gp.rightThumbstickButton, name: "R3")
    }

    private func detach() {
        controller = nil
        controllerName = "none"
        lx = 0; ly = 0; rx = 0; ry = 0
    }

    private func tick() {
        let s = AppSettings.shared
        guard s.enabled else { return }
        guard Accessibility.isTrusted else { return }

        let accel = Float(s.pointerAcceleration)
        var dx = applyDeadzone(lx, dz: Float(s.deadzone)) * Float(s.cursorSpeed) * accel
        var dy = applyDeadzone(ly, dz: Float(s.deadzone)) * Float(s.cursorSpeed) * accel

        if s.invertY { dy = -dy }

        if dx != 0 || dy != 0 {
            MouseEvents.moveBy(dx: CGFloat(dx), dy: CGFloat(dy))
        }

        let rawScrollY = applyDeadzone(ry, dz: Float(s.deadzone)) * Float(s.scrollSpeed)
        let rawScrollX = applyDeadzone(rx, dz: Float(s.deadzone)) * Float(s.scrollSpeed)
        var scrollY = rawScrollY
        if s.invertScrollY { scrollY = -scrollY }
        let scrollX = s.horizontalScrollEnabled ? rawScrollX : 0
        if scrollX != 0 || scrollY != 0 {
            MouseEvents.scroll(dx: Int32(scrollX), dy: Int32(-scrollY))
        }
    }

    private func applyDeadzone(_ v: Float, dz: Float) -> Float {
        abs(v) < dz ? 0 : v
    }

    private func bindButton(_ input: GCControllerButtonInput?, name: String) {
        guard let input else { return }
        let existingHandler = input.pressedChangedHandler
        input.pressedChangedHandler = { [weak self] button, value, pressed in
            existingHandler?(button, value, pressed)
            self?.handleButtonPress(name: name, pressed: pressed)
        }
    }

    private func handleButtonPress(name: String, pressed: Bool) {
        guard Accessibility.isTrusted else { return }
        guard !ShortcutRecordingState.shared.isRecording else { return }
        let button = ControllerButton(name)
        guard let shortcut = ShortcutStore.shared.shortcut(for: button) else { return }
        switch shortcut {
        case .mouse(let mouseButton):
            handleMouseShortcut(mouseButton, pressed: pressed)
        case .keyboard:
            if pressed { ShortcutPerformer.perform(shortcut) }
        }
    }

    private func handleMouseShortcut(_ button: MouseButton, pressed: Bool) {
        switch button {
        case .left:
            pressed ? MouseEvents.leftDown() : MouseEvents.leftUp()
        case .right:
            pressed ? MouseEvents.rightDown() : MouseEvents.rightUp()
        case .middle:
            pressed ? MouseEvents.middleDown() : MouseEvents.middleUp()
        }
    }
}
