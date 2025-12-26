//
//  ControllerMouseService.swift
//  Mouse Controller
//
//  Created by Lian on 25.12.25.
//


import Foundation
import GameController
import Combine
import CoreHaptics
import AppKit

@MainActor
final class ControllerMouseService: ObservableObject {
    static let shared = ControllerMouseService()
    private init() {}

    @Published private(set) var controllerName: String = "none"
    @Published private(set) var activeButtons: Set<ControllerButton> = []

    private var controller: GCController?
    private var timer: Timer?
    private var gameModeTimer: Timer?
    private var activity: NSObjectProtocol?
    private var gameModeActive: Bool = false
    private var gameModePriorEnabled: Bool?
    private var hapticsEngine: CHHapticEngine?

    private var lx: Float = 0
    private var ly: Float = 0
    private var ry: Float = 0
    private var rx: Float = 0
    private var lastLeftDirection: JoystickDirection?
    private var lastRightDirection: JoystickDirection?
    private var experimentalCenter: CGPoint?
    private var lastPointerMagnitude: Float = 0
    private var lastPointerUpdate: TimeInterval = 0

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
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.attach(c)
            }
        }
        NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] n in
            guard let c = n.object as? GCController else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.controller === c { self.detach() }
            }
        }

        GCController.startWirelessControllerDiscovery(completionHandler: nil)
        if let c = GCController.controllers().first { attach(c) }

        timer?.invalidate()
        let t = Timer(timeInterval: 1.0/120.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func setEnabled(_ enabled: Bool) {
        if !enabled {
            activeButtons.removeAll()
            MouseEvents.leftUp()
            MouseEvents.rightUp()
            MouseEvents.middleUp()
        }
    }

    func vibrateDoublePulse() {
        guard let controller else { return }
        guard let haptics = controller.haptics else { return }
        do {
            if hapticsEngine == nil {
                hapticsEngine = try haptics.createEngine(withLocality: .default)
                try hapticsEngine?.start()
            }
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 5)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 3)
            let first = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
            let second = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0.18)
            let pattern = try CHHapticPattern(events: [first, second], parameters: [])
            let player = try hapticsEngine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play controller haptics: \(error.localizedDescription)")
        }
    }

    private func attach(_ c: GCController) {
        controller = c
        controllerName = c.vendorName ?? "controller"

        if let gp = c.extendedGamepad {
            wireExtendedGamepad(gp)
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
        activeButtons.removeAll()
    }

    private func tick() {
        let s = AppSettings.shared
        guard s.enabled else { return }
        guard Accessibility.isTrusted else { return }

        let accel = Float(s.pointerAcceleration)
        let isRecording = ShortcutRecordingState.shared.isRecording
        let pointerStick = s.swapSticks ? JoystickStick.right : .left
        let scrollStick = s.swapSticks ? JoystickStick.left : .right
        let pointerStickMapped = !isRecording && ShortcutStore.shared.hasStickBindings(pointerStick)
        let scrollStickMapped = !isRecording && ShortcutStore.shared.hasStickBindings(scrollStick)
        let (pointerX, pointerY) = axes(for: pointerStick)
        let (scrollX, scrollY) = axes(for: scrollStick)

        let pointerActive = !(pointerStickMapped || isRecording)
        let scrollActive = !(scrollStickMapped || isRecording)

        if s.experimentalTeleportEnabled, pointerActive {
            updateExperimentalPointer(settings: s, x: pointerX, y: pointerY)
        } else {
            experimentalCenter = nil
            var dx = pointerActive ? applyDeadzone(pointerX, dz: Float(s.deadzone)) * Float(s.cursorSpeed) * accel : 0
            var dy = pointerActive ? applyDeadzone(pointerY, dz: Float(s.deadzone)) * Float(s.cursorSpeed) * accel : 0

            if s.invertY { dy = -dy }
            if s.invertX { dx = -dx }

            if dx != 0 || dy != 0 {
                MouseEvents.moveBy(dx: CGFloat(dx), dy: CGFloat(dy))
            }
        }

        // Only allow scrolling when the designated scroll stick is active and not used for pointing
        let scrollEnabled = scrollActive && scrollStick != pointerStick
        let rawScrollY = scrollEnabled ? applyDeadzone(scrollY, dz: Float(s.deadzone)) * Float(s.scrollSpeed) : 0
        let rawScrollX = scrollEnabled ? applyDeadzone(scrollX, dz: Float(s.deadzone)) * Float(s.scrollSpeed) : 0
        var adjustedScrollY = rawScrollY
        if s.invertScrollY { adjustedScrollY = -adjustedScrollY }
        var adjustedScrollX = s.horizontalScrollEnabled ? rawScrollX : 0
        if s.invertScrollX { adjustedScrollX = -adjustedScrollX }
        if adjustedScrollX != 0 || adjustedScrollY != 0 {
            MouseEvents.scroll(dx: Int32(adjustedScrollX), dy: Int32(-adjustedScrollY))
        }
    }

    private func wireExtendedGamepad(_ gp: GCExtendedGamepad) {
        let existingLeftHandler = gp.leftThumbstick.valueChangedHandler
        gp.leftThumbstick.valueChangedHandler = { [weak self] stick, x, y in
            existingLeftHandler?(stick, x, y)
            self?.lx = x
            self?.ly = y
            self?.handleJoystickDirection(stick: .left, x: x, y: y)
        }
        let existingRightHandler = gp.rightThumbstick.valueChangedHandler
        gp.rightThumbstick.valueChangedHandler = { [weak self] stick, x, y in
            existingRightHandler?(stick, x, y)
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

    private func updateExperimentalPointer(settings: AppSettings, x: Float, y: Float) {
        let now = CFAbsoluteTimeGetCurrent()
        let dz = Float(settings.deadzone)
        var x = applyDeadzone(x, dz: dz)
        var y = applyDeadzone(y, dz: dz)

        if settings.invertX { x = -x }
        if settings.invertY { y = -y }

        let magnitude = hypot(x, y)
        let timeDelta = lastPointerUpdate == 0 ? 0 : now - lastPointerUpdate
        let quickRelease = magnitude == 0 && lastPointerMagnitude > 0.35 && timeDelta < 0.08

        if experimentalCenter == nil {
            experimentalCenter = MouseEvents.location()
        } else if quickRelease {
            experimentalCenter = MouseEvents.location()
        }

        if let center = experimentalCenter {
            let radius = CGFloat(settings.experimentalTeleportRadius)
            let target = CGPoint(x: center.x + CGFloat(x) * radius,
                                 y: center.y - CGFloat(y) * radius)

            // Bounce animation toward target with slight overshoot
            // Parameters can be tuned via AppSettings in the future
            let totalSteps = 8
            let stepInterval: TimeInterval = 1.0 / 480.0 // ~16.6ms over ~133ms total
            let overshoot: CGFloat = 1.12 // 12% overshoot for a subtle bounce

            let start = MouseEvents.location()
            let to = target

            // Precompute a spring-like easing (easeOutBack style)
            func easeOutBack(_ t: CGFloat) -> CGFloat {
                // s ~= 1.70158 (back overshoot constant)
                let s: CGFloat = 1.70158
                let inv = t - 1
                return 1 + (inv * inv) * ((s + 1) * inv + s)
            }

            // Schedule incremental moves on the main runloop to avoid blocking
            for i in 1...totalSteps {
                let when = DispatchTime.now() + stepInterval * Double(i)
                DispatchQueue.main.asyncAfter(deadline: when) {
                    let p = CGFloat(i) / CGFloat(totalSteps)
                    // Compose overshoot by extending the end point once near completion
                    let eased = easeOutBack(p)
                    let currentTarget = CGPoint(
                        x: start.x + (to.x - start.x) * eased * overshoot,
                        y: start.y + (to.y - start.y) * eased * overshoot
                    )
                    MouseEvents.moveTo(currentTarget)

                    // Final settle exactly at `to` on last step
                    if i == totalSteps {
                        MouseEvents.moveTo(to)
                    }
                }
            }
        }

        lastPointerMagnitude = magnitude
        lastPointerUpdate = now
    }

    private func axes(for stick: JoystickStick) -> (Float, Float) {
        switch stick {
        case .left:
            return (lx, ly)
        case .right:
            return (rx, ry)
        }
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
        guard AppSettings.shared.enabled else { return }
        guard !ShortcutRecordingState.shared.isRecording else { return }
        let button = ControllerButton(name)
        guard let shortcut = ShortcutStore.shared.shortcut(for: button) else { return }
        updateActiveButton(button, pressed: pressed)
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
        guard AppSettings.shared.enabled else { return }
        let direction = JoystickBinding.direction(forX: x, y: y)
        if ShortcutRecordingState.shared.isRecording {
            if stick == .left {
                lastLeftDirection = direction
            } else {
                lastRightDirection = direction
            }
            return
        }
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


    private func updateActiveButton(_ button: ControllerButton, pressed: Bool) {
        if pressed {
            activeButtons.insert(button)
        } else {
            activeButtons.remove(button)
        }
    }
}
