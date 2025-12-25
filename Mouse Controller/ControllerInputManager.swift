import Foundation
import GameController

final class ControllerInputManager {
    static let shared = ControllerInputManager()

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
        // Face buttons
        gp.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("ButtonA") } }
        gp.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("ButtonB") } }
        gp.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("ButtonX") } }
        gp.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("ButtonY") } }

        // Shoulders
        gp.leftShoulder.pressedChangedHandler  = { [weak self] _, _, pressed in if pressed { self?.postDetected("L1") } }
        gp.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("R1") } }

        // Triggers
        gp.leftTrigger.pressedChangedHandler   = { [weak self] _, _, pressed in if pressed { self?.postDetected("L2") } }
        gp.rightTrigger.pressedChangedHandler  = { [weak self] _, _, pressed in if pressed { self?.postDetected("R2") } }

        // D-pad
        gp.dpad.up.pressedChangedHandler       = { [weak self] _, _, pressed in if pressed { self?.postDetected("DPadUp") } }
        gp.dpad.down.pressedChangedHandler     = { [weak self] _, _, pressed in if pressed { self?.postDetected("DPadDown") } }
        gp.dpad.left.pressedChangedHandler     = { [weak self] _, _, pressed in if pressed { self?.postDetected("DPadLeft") } }
        gp.dpad.right.pressedChangedHandler    = { [weak self] _, _, pressed in if pressed { self?.postDetected("DPadRight") } }

        // Menu/Options buttons (if available)
        gp.buttonMenu.pressedChangedHandler    = { [weak self] _, _, pressed in if pressed { self?.postDetected("Menu") } }
        gp.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("Options") } }
        gp.buttonHome?.pressedChangedHandler    = { [weak self] _, _, pressed in if pressed { self?.postDetected("Home") } }

        // Thumbstick buttons (if available)
        gp.leftThumbstickButton?.pressedChangedHandler  = { [weak self] _, _, pressed in if pressed { self?.postDetected("L3") } }
        gp.rightThumbstickButton?.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("R3") } }
    }

    private func wireMicroGamepad(_ gp: GCMicroGamepad) {
        gp.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("ButtonA") } }
        gp.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("ButtonX") } }
        gp.dpad.up.pressedChangedHandler    = { [weak self] _, _, pressed in if pressed { self?.postDetected("DPadUp") } }
        gp.dpad.down.pressedChangedHandler  = { [weak self] _, _, pressed in if pressed { self?.postDetected("DPadDown") } }
        gp.dpad.left.pressedChangedHandler  = { [weak self] _, _, pressed in if pressed { self?.postDetected("DPadLeft") } }
        gp.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("DPadRight") } }
    }

    private func wireGamepad(_ gp: GCGamepad) {
        gp.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("ButtonA") } }
        gp.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("ButtonB") } }
        gp.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("ButtonX") } }
        gp.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("ButtonY") } }
        gp.dpad.up.pressedChangedHandler    = { [weak self] _, _, pressed in if pressed { self?.postDetected("DPadUp") } }
        gp.dpad.down.pressedChangedHandler  = { [weak self] _, _, pressed in if pressed { self?.postDetected("DPadDown") } }
        gp.dpad.left.pressedChangedHandler  = { [weak self] _, _, pressed in if pressed { self?.postDetected("DPadLeft") } }
        gp.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in if pressed { self?.postDetected("DPadRight") } }
    }

    private func postDetected(_ name: String) {
        NotificationCenter.default.post(
            name: Notification.Name("ControllerButtonDetected"),
            object: nil,
            userInfo: ["name": name]
        )
    }
}
