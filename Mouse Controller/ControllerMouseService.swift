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
    private var lastLeftDirection: JoystickDirection?
    private var lastRightDirection: JoystickDirection?
    private var experimentalCenter: CGPoint?
    private var lastLeftMagnitude: Float = 0
    private var lastLeftUpdate: TimeInterval = 0

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

        if let gp = c.extendedGamepad {
            wireExtendedGamepad(gp)
        }

        if let gp = c.gamepad {
            wireGamepad(gp)
        }

        if let gp = c.microGamepad {
            wireMicroGamepad(gp)
        }
    }

    private func detach() {
        controller = nil
        controllerName = "none"
        lx = 0; ly = 0; rx = 0; ry = 0
        lastLeftDirection = nil
        lastRightDirection = nil
    }

    private func tick() {
        let s = AppSettings.shared
        guard s.enabled else { return }
        guard Accessibility.isTrusted else { return }

        let accel = Float(s.pointerAcceleration)
        let leftStickMapped = ShortcutStore.shared.hasStickBindings(.left)
        let rightStickMapped = ShortcutStore.shared.hasStickBindings(.right)

        if s.experimentalTeleportEnabled, !leftStickMapped {
            updateExperimentalPointer(settings: s)
        } else {
            experimentalCenter = nil
            var dx = leftStickMapped ? 0 : applyDeadzone(lx, dz: Float(s.deadzone)) * Float(s.cursorSpeed) * accel
            var dy = leftStickMapped ? 0 : applyDeadzone(ly, dz: Float(s.deadzone)) * Float(s.cursorSpeed) * accel

            if s.invertY { dy = -dy }
            if s.invertX { dx = -dx }

            if dx != 0 || dy != 0 {
                MouseEvents.moveBy(dx: CGFloat(dx), dy: CGFloat(dy))
            }
        }

        let rawScrollY = rightStickMapped ? 0 : applyDeadzone(ry, dz: Float(s.deadzone)) * Float(s.scrollSpeed)
        let rawScrollX = rightStickMapped ? 0 : applyDeadzone(rx, dz: Float(s.deadzone)) * Float(s.scrollSpeed)
        var scrollY = rawScrollY
        if s.invertScrollY { scrollY = -scrollY }
        var scrollX = s.horizontalScrollEnabled ? rawScrollX : 0
        if s.invertScrollX { scrollX = -scrollX }
        if scrollX != 0 || scrollY != 0 {
            MouseEvents.scroll(dx: Int32(scrollX), dy: Int32(-scrollY))
        }
    }

    private func wireExtendedGamepad(_ gp: GCExtendedGamepad) {
        gp.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            self?.lx = x
            self?.ly = y
            self?.handleJoystickDirection(stick: .left, x: x, y: y)
        }
        gp.rightThumbstick.valueChangedHandler = { [weak self] _, x, y in
            self?.rx = x
            self?.ry = y
            self?.handleJoystickDirection(stick: .right, x: x, y: y)
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

    private func wireGamepad(_ gp: GCGamepad) {
        bindButton(gp.buttonA, name: "ButtonA")
        bindButton(gp.buttonB, name: "ButtonB")
        bindButton(gp.buttonX, name: "ButtonX")
        bindButton(gp.buttonY, name: "ButtonY")

        bindButton(gp.leftShoulder, name: "L1")
        bindButton(gp.rightShoulder, name: "R1")

        bindButton(gp.dpad.up, name: "DPadUp")
        bindButton(gp.dpad.down, name: "DPadDown")
        bindButton(gp.dpad.left, name: "DPadLeft")
        bindButton(gp.dpad.right, name: "DPadRight")
    }

    private func wireMicroGamepad(_ gp: GCMicroGamepad) {
        bindButton(gp.buttonA, name: "ButtonA")
        bindButton(gp.buttonX, name: "ButtonX")
        bindButton(gp.dpad.up, name: "DPadUp")
        bindButton(gp.dpad.down, name: "DPadDown")
        bindButton(gp.dpad.left, name: "DPadLeft")
        bindButton(gp.dpad.right, name: "DPadRight")
        bindButton(gp.buttonMenu, name: "Menu")
    }

    private func applyDeadzone(_ v: Float, dz: Float) -> Float {
        abs(v) < dz ? 0 : v
    }

    private func updateExperimentalPointer(settings: AppSettings) {
        let now = CFAbsoluteTimeGetCurrent()
        let dz = Float(settings.deadzone)
        var x = applyDeadzone(lx, dz: dz)
        var y = applyDeadzone(ly, dz: dz)

        if settings.invertX { x = -x }
        if settings.invertY { y = -y }

        let magnitude = hypot(x, y)
        let timeDelta = lastLeftUpdate == 0 ? 0 : now - lastLeftUpdate
        let quickRelease = magnitude == 0 && lastLeftMagnitude > 0.35 && timeDelta < 0.08

        if experimentalCenter == nil {
            experimentalCenter = MouseEvents.location()
        } else if quickRelease {
            experimentalCenter = MouseEvents.location()
        }

        if let center = experimentalCenter {
            let radius = CGFloat(settings.experimentalTeleportRadius)
            let target = CGPoint(x: center.x + CGFloat(x) * radius,
                                 y: center.y - CGFloat(y) * radius)
            MouseEvents.moveTo(target)
        }

        lastLeftMagnitude = magnitude
        lastLeftUpdate = now
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

    private func handleJoystickDirection(stick: JoystickStick, x: Float, y: Float) {
        guard Accessibility.isTrusted else { return }
        guard !ShortcutRecordingState.shared.isRecording else { return }
        let direction = JoystickBinding.direction(forX: x, y: y)
        let lastDirection = stick == .left ? lastLeftDirection : lastRightDirection
        guard direction != lastDirection else { return }

        if let lastDirection {
            let name = JoystickBinding.buttonName(for: stick, direction: lastDirection)
            handleButtonPress(name: name, pressed: false)
        }

        if let direction {
            let name = JoystickBinding.buttonName(for: stick, direction: direction)
            handleButtonPress(name: name, pressed: true)
        }

        if stick == .left {
            lastLeftDirection = direction
        } else {
            lastRightDirection = direction
        }
    }
}
