import Foundation
import GameController

final class ControllerInputManager {
    static let shared = ControllerInputManager()

    private var lastLeftDirection: JoystickDirection?
    private var lastRightDirection: JoystickDirection?

    private init() {
        // Observe new controllers
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            self?.wire(controller: controller)
        }

        // Wire any controllers already connected
        GCController.controllers().forEach { wire(controller: $0) }

        // Start discovery (optional, but helps on macOS if nothing is connected yet)
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
    }

    private func wire(controller: GCController) {
        if let eg = controller.extendedGamepad {
            wireExtendedGamepad(eg)
        }
        if let mg = controller.microGamepad {
            wireMicroGamepad(mg)
        }
        if let g = controller.gamepad {
            wireGamepad(g)
        }
    }

    private func wireExtendedGamepad(_ gp: GCExtendedGamepad) {
        let leftHandler = gp.leftThumbstick.valueChangedHandler
        gp.leftThumbstick.valueChangedHandler = { [weak self] stick, x, y in
            leftHandler?(stick, x, y)
            self?.handleJoystickInput(stick: .left, x: x, y: y)
        }
        let rightHandler = gp.rightThumbstick.valueChangedHandler
        gp.rightThumbstick.valueChangedHandler = { [weak self] stick, x, y in
            rightHandler?(stick, x, y)
            self?.handleJoystickInput(stick: .right, x: x, y: y)
        }

        // Face buttons
        attachDetection(to: gp.buttonA, name: "ButtonA")
        attachDetection(to: gp.buttonB, name: "ButtonB")
        attachDetection(to: gp.buttonX, name: "ButtonX")
        attachDetection(to: gp.buttonY, name: "ButtonY")

        // Shoulders
        attachDetection(to: gp.leftShoulder, name: "L1")
        attachDetection(to: gp.rightShoulder, name: "R1")

        // Triggers
        attachDetection(to: gp.leftTrigger, name: "L2")
        attachDetection(to: gp.rightTrigger, name: "R2")

        // D-pad
        attachDetection(to: gp.dpad.up, name: "DPadUp")
        attachDetection(to: gp.dpad.down, name: "DPadDown")
        attachDetection(to: gp.dpad.left, name: "DPadLeft")
        attachDetection(to: gp.dpad.right, name: "DPadRight")

        // Menu/Options buttons (if available)
        attachDetection(to: gp.buttonMenu, name: "Menu")
        attachDetection(to: gp.buttonOptions, name: "Options")
        attachDetection(to: gp.buttonHome, name: "Home")

        // Thumbstick buttons (if available)
        attachDetection(to: gp.leftThumbstickButton, name: "L3")
        attachDetection(to: gp.rightThumbstickButton, name: "R3")
    }

    private func wireMicroGamepad(_ gp: GCMicroGamepad) {
        attachDetection(to: gp.buttonA, name: "ButtonA")
        attachDetection(to: gp.buttonX, name: "ButtonX")
        attachDetection(to: gp.dpad.up, name: "DPadUp")
        attachDetection(to: gp.dpad.down, name: "DPadDown")
        attachDetection(to: gp.dpad.left, name: "DPadLeft")
        attachDetection(to: gp.dpad.right, name: "DPadRight")
    }

    private func wireGamepad(_ gp: GCGamepad) {
        attachDetection(to: gp.buttonA, name: "ButtonA")
        attachDetection(to: gp.buttonB, name: "ButtonB")
        attachDetection(to: gp.buttonX, name: "ButtonX")
        attachDetection(to: gp.buttonY, name: "ButtonY")
        attachDetection(to: gp.dpad.up, name: "DPadUp")
        attachDetection(to: gp.dpad.down, name: "DPadDown")
        attachDetection(to: gp.dpad.left, name: "DPadLeft")
        attachDetection(to: gp.dpad.right, name: "DPadRight")
    }

    private func attachDetection(to input: GCControllerButtonInput?, name: String) {
        guard let input else { return }
        let existingHandler = input.pressedChangedHandler
        input.pressedChangedHandler = { [weak self] button, value, pressed in
            existingHandler?(button, value, pressed)
            if pressed { self?.postDetected(name) }
        }
    }

    private func handleJoystickInput(stick: JoystickStick, x: Float, y: Float) {
        let direction = JoystickBinding.direction(forX: x, y: y)
        let lastDirection = stick == .left ? lastLeftDirection : lastRightDirection
        guard direction != lastDirection else { return }
        if let direction {
            postDetected(JoystickBinding.buttonName(for: stick, direction: direction))
        }
        if stick == .left {
            lastLeftDirection = direction
        } else {
            lastRightDirection = direction
        }
    }

    private func postDetected(_ name: String) {
        NotificationCenter.default.post(
            name: Notification.Name("ControllerButtonDetected"),
            object: nil,
            userInfo: ["name": name]
        )
    }
}
