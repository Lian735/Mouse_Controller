import Foundation
import ApplicationServices
import Combine
import AppKit
import IOKit.hidsystem

enum MouseButton: Int, Codable, CaseIterable, CustomStringConvertible {
    case left = 0
    case right = 1
    case middle = 2

    var description: String {
        switch self { case .left: return "Left Click"; case .right: return "Right Click"; case .middle: return "Middle Click" }
    }
}

struct KeyboardShortcut: Codable, Equatable {
    var keyCode: CGKeyCode?
    var systemKey: Int32?
    var modifiers: CGEventFlags

    private enum CodingKeys: String, CodingKey { case keyCode, systemKey, modifiers }

    init(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.systemKey = nil
        self.modifiers = modifiers
    }

    init(systemKey: Int32, modifiers: CGEventFlags) {
        self.keyCode = nil
        self.systemKey = systemKey
        self.modifiers = modifiers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let modifiersRaw = try container.decode(UInt64.self, forKey: .modifiers)
        self.modifiers = CGEventFlags(rawValue: modifiersRaw)
        if let systemKey = try container.decodeIfPresent(Int32.self, forKey: .systemKey) {
            self.systemKey = systemKey
            self.keyCode = nil
        } else if let keyCodeRaw = try container.decodeIfPresent(UInt16.self, forKey: .keyCode) {
            self.keyCode = CGKeyCode(keyCodeRaw)
            self.systemKey = nil
        } else {
            self.keyCode = nil
            self.systemKey = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
        if let keyCode {
            try container.encode(UInt16(keyCode), forKey: .keyCode)
        }
        if let systemKey {
            try container.encode(systemKey, forKey: .systemKey)
        }
    }
}

enum Shortcut: Codable, Equatable, CustomStringConvertible {
    case keyboard(KeyboardShortcut)
    case mouse(MouseButton)

    var description: String {
        switch self {
        case .keyboard(let k):
            return ShortcutFormatter.format(modifiers: k.modifiers, keyCode: k.keyCode, systemKey: k.systemKey)
        case .mouse(let b):
            return b.description
        }
    }
}

struct ControllerButton: Hashable, Codable, CustomStringConvertible {
    let name: String

    init(_ name: String) { self.name = name }

    var description: String { name }
}

enum JoystickStick: String, CaseIterable {
    case left
    case right
}

enum JoystickDirection: String, CaseIterable {
    case up
    case down
    case left
    case right
}

enum JoystickBinding {
    static let activationThreshold: Float = 0.7

    static func buttonName(for stick: JoystickStick, direction: JoystickDirection) -> String {
        "Joystick\(stick.rawValue.capitalized)\(direction.rawValue.capitalized)"
    }

    static func button(for stick: JoystickStick, direction: JoystickDirection) -> ControllerButton {
        ControllerButton(buttonName(for: stick, direction: direction))
    }

    static func buttons(for stick: JoystickStick) -> [ControllerButton] {
        JoystickDirection.allCases.map { button(for: stick, direction: $0) }
    }

    static func stick(for name: String) -> JoystickStick? {
        if name.hasPrefix("JoystickLeft") { return .left }
        if name.hasPrefix("JoystickRight") { return .right }
        return nil
    }

    static func direction(for name: String) -> JoystickDirection? {
        if name.hasSuffix("Up") { return .up }
        if name.hasSuffix("Down") { return .down }
        if name.hasSuffix("Left") { return .left }
        if name.hasSuffix("Right") { return .right }
        return nil
    }

    static func direction(forX x: Float, y: Float, threshold: Float = activationThreshold) -> JoystickDirection? {
        let maxAxis = max(abs(x), abs(y))
        guard maxAxis >= threshold else { return nil }
        if abs(x) > abs(y) {
            return x > 0 ? .right : .left
        }
        return y > 0 ? .up : .down
    }
}

extension ControllerButton {
    var displayName: String {
        if let stick = JoystickBinding.stick(for: name),
           let direction = JoystickBinding.direction(for: name) {
            return "Joystick \(stick.rawValue.capitalized) \(direction.rawValue.capitalized)"
        }
        if name.hasPrefix("DPad") {
            let suffix = name.replacingOccurrences(of: "DPad", with: "")
            return "D-Pad \(suffix)"
        }
        if name == "L1" { return "L1 (Left Shoulder)" }
        if name == "R1" { return "R1 (Right Shoulder)" }
        if name == "L2" { return "L2 (Left Trigger)" }
        if name == "R2" { return "R2 (Right Trigger)" }
        if name == "L3" { return "L3 (Left Stick)" }
        if name == "R3" { return "R3 (Right Stick)" }
        return name
    }
}

@MainActor
final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()
    private init() {
        let loaded = load()
        if !loaded {
            bindings = Self.defaultBindings
        } else if bindings.isEmpty {
            bindings = Self.defaultBindings
        }
        loadVibration()
    }

    @Published var bindings: [ControllerButton: Shortcut?] = [:] { didSet { save() } }
    @Published var vibrationEnabled: [ControllerButton: Bool] = [:] { didSet { saveVibration() } }

    private let d = UserDefaults.standard
    private let k = "ControllerMouseShortcuts"
    private let kVibration = "ControllerMouseVibration"

    private static let defaultBindings: [ControllerButton: Shortcut?] = [
        ControllerButton("ButtonA"): .some(.mouse(.left)),
        ControllerButton("ButtonB"): .some(.mouse(.right))
    ]

    @discardableResult
    private func load() -> Bool {
        guard let data = d.data(forKey: k) else { return false }
        if let decoded = try? JSONDecoder().decode([ControllerButton: Shortcut?].self, from: data) {
            bindings = decoded
            return true
        }
        return false
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bindings) {
            d.set(data, forKey: k)
        }
    }

    private func loadVibration() {
        if let data = d.data(forKey: kVibration),
           let decoded = try? JSONDecoder().decode([ControllerButton: Bool].self, from: data) {
            vibrationEnabled = decoded
        }
    }

    private func saveVibration() {
        if let data = try? JSONEncoder().encode(vibrationEnabled) {
            d.set(data, forKey: kVibration)
        }
    }

    func set(_ shortcut: Shortcut?, for button: ControllerButton) {
        if let s = shortcut {
            bindings[button] = .some(s)
        } else {
            bindings[button] = .some(nil)
        }
    }

    func shortcut(for button: ControllerButton) -> Shortcut? { bindings[button] ?? nil }

    func isVibrationEnabled(for button: ControllerButton) -> Bool { vibrationEnabled[button] ?? false }
    func setVibration(_ enabled: Bool, for button: ControllerButton) { vibrationEnabled[button] = enabled }

    func reset() {
        bindings.removeAll()
        d.removeObject(forKey: k)
        objectWillChange.send()
    }

    func ensureButton(_ button: ControllerButton) {
        if bindings[button] == nil {
            bindings[button] = .some(nil)
        }
    }

    func ensureButtons(_ buttons: [ControllerButton]) {
        for button in buttons {
            ensureButton(button)
        }
    }

    func hasStickBindings(_ stick: JoystickStick) -> Bool {
        bindings.keys.contains { JoystickBinding.stick(for: $0.name) == stick }
    }

    func removeStickBindings(for button: ControllerButton) {
        guard let stick = JoystickBinding.stick(for: button.name) else { return }
        let buttons = JoystickBinding.buttons(for: stick)
        for stickButton in buttons {
            bindings.removeValue(forKey: stickButton)
        }
    }

    func removeButton(_ button: ControllerButton) {
        bindings.removeValue(forKey: button)
    }
}

enum ShortcutPerformer {
    static func perform(_ shortcut: Shortcut) {
        #if DEBUG
        print("Performing shortcut: \(shortcut)")
        #endif
        switch shortcut {
        case .mouse(let button):
            performMouse(button)
        case .keyboard(let ks):
            performKeyboard(ks)
        }
    }

    private static func performMouse(_ button: MouseButton) {
        let p = MouseEvents.location()
        guard let src = CGEventSource(stateID: .hidSystemState) else {
            #if DEBUG
            print("Failed to create CGEventSource; check Accessibility permissions.")
            #endif
            return
        }
        let typeDown: CGEventType
        let typeUp: CGEventType
        let cgButton: CGMouseButton
        switch button {
        case .left: typeDown = .leftMouseDown; typeUp = .leftMouseUp; cgButton = .left
        case .right: typeDown = .rightMouseDown; typeUp = .rightMouseUp; cgButton = .right
        case .middle: typeDown = .otherMouseDown; typeUp = .otherMouseUp; cgButton = .center
        }
        if let e1 = CGEvent(mouseEventSource: src, mouseType: typeDown, mouseCursorPosition: p, mouseButton: cgButton) {
            e1.post(tap: .cghidEventTap)
        } else {
            #if DEBUG
            print("Failed to create mouse down event.")
            #endif
        }
        if let e2 = CGEvent(mouseEventSource: src, mouseType: typeUp, mouseCursorPosition: p, mouseButton: cgButton) {
            e2.post(tap: .cghidEventTap)
        } else {
            #if DEBUG
            print("Failed to create mouse up event.")
            #endif
        }
    }

    private static func performKeyboard(_ ks: KeyboardShortcut) {
        guard let src = CGEventSource(stateID: .hidSystemState) else {
            #if DEBUG
            print("Failed to create CGEventSource; check Accessibility permissions.")
            #endif
            return
        }
        var modifiersToPress = ks.modifiers
        if let flag = ModifierKeyMapping.flag(for: ks.keyCode) {
            modifiersToPress = modifiersToPress.subtracting(flag)
        }
        // Press modifiers
        for (flag, code) in ModifierKeyMapping.modifierKeyCodes where modifiersToPress.contains(flag) {
            if let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true) {
                e.flags = flag
                e.post(tap: .cghidEventTap)
            } else {
                #if DEBUG
                print("Failed to create key down for modifier: \(flag)")
                #endif
            }
        }

        if let systemKey = ks.systemKey {
            postSystemKey(systemKey, modifiers: ks.modifiers)
        } else if let keyCode = ks.keyCode {
            if let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true) {
                down.flags = ks.modifiers
                down.post(tap: .cghidEventTap)
            } else {
                #if DEBUG
                print("Failed to create key down for keyCode: \(keyCode)")
                #endif
            }
            if let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) {
                up.flags = ks.modifiers
                up.post(tap: .cghidEventTap)
            } else {
                #if DEBUG
                print("Failed to create key up for keyCode: \(keyCode)")
                #endif
            }
        }

        // Release modifiers
        for (flag, code) in ModifierKeyMapping.modifierKeyCodes.reversed() where modifiersToPress.contains(flag) {
            if let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false) {
                e.flags = flag
                e.post(tap: .cghidEventTap)
            } else {
                #if DEBUG
                print("Failed to create key up for modifier: \(flag)")
                #endif
            }
        }
    }

    private static func postSystemKey(_ key: Int32, modifiers: CGEventFlags) {
        let keyDownData = systemKeyData(key: key, keyDown: true)
        let keyUpData = systemKeyData(key: key, keyDown: false)

        if let down = systemEvent(data1: keyDownData, modifiers: modifiers) {
            down.post(tap: .cghidEventTap)
        } else {
            #if DEBUG
            print("Failed to create system-defined key down for key: \(key)")
            #endif
        }
        if let up = systemEvent(data1: keyUpData, modifiers: modifiers) {
            up.post(tap: .cghidEventTap)
        } else {
            #if DEBUG
            print("Failed to create system-defined key up for key: \(key)")
            #endif
        }
    }

    private static func systemKeyData(key: Int32, keyDown: Bool) -> Int32 {
        let state: Int32 = keyDown ? 0xA00 : 0xB00
        return (key << 16) | state
    }

    private static func systemEvent(data1: Int32, modifiers: CGEventFlags) -> CGEvent? {
        let nsEvent = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: Int16(NX_SUBTYPE_AUX_CONTROL_BUTTONS),
            data1: Int(data1),
            data2: -1
        )
        return nsEvent?.cgEvent
    }
}

enum ShortcutFormatter {
    static func format(modifiers: CGEventFlags, keyCode: CGKeyCode?, systemKey: Int32?) -> String {
        var parts: [String] = []
        var displayModifiers = modifiers
        if let keyCode, let flag = ModifierKeyMapping.flag(for: keyCode) {
            displayModifiers = displayModifiers.subtracting(flag)
        }
        if displayModifiers.contains(.maskCommand) { parts.append("⌘") }
        if displayModifiers.contains(.maskShift) { parts.append("⇧") }
        if displayModifiers.contains(.maskAlternate) { parts.append("⌥") }
        if displayModifiers.contains(.maskControl) { parts.append("⌃") }
        if let systemKey {
            parts.append(SystemKeyNames.name(for: systemKey))
        } else if let keyCode {
            parts.append(KeyCodeNames.name(for: keyCode))
        } else {
            parts.append("Unknown")
        }
        return parts.joined()
    }
}

enum KeyCodeNames {
    static func name(for keyCode: CGKeyCode) -> String {
        // Minimal mapping; fall back to hex code
        switch keyCode {
        case 0x38, 0x3C: return "Shift"
        case 0x3B, 0x3E: return "Control"
        case 0x3A, 0x3D: return "Option"
        case 0x37, 0x36: return "Command"
        case 0x39: return "Caps Lock"
        case 0x08: return "C"
        case 0x00: return "A"
        case 0x0B: return "B"
        case 0x0C: return "="
        default: return String(format: "0x%02X", keyCode)
        }
    }
}

enum SystemKeyNames {
    static func name(for key: Int32) -> String {
        switch key {
        case NX_KEYTYPE_MISSION_CONTROL: return "Mission Control"
        case NX_KEYTYPE_LAUNCHPAD: return "Launchpad"
        case NX_KEYTYPE_BRIGHTNESS_UP: return "Brightness Up"
        case NX_KEYTYPE_BRIGHTNESS_DOWN: return "Brightness Down"
        case NX_KEYTYPE_SOUND_UP: return "Sound Up"
        case NX_KEYTYPE_SOUND_DOWN: return "Sound Down"
        case NX_KEYTYPE_MUTE: return "Mute"
        case NX_KEYTYPE_PLAY: return "Play/Pause"
        case NX_KEYTYPE_FAST: return "Next"
        case NX_KEYTYPE_REWIND: return "Previous"
        default: return String(format: "System 0x%02X", key)
        }
    }
}

enum ModifierKeyMapping {
    static let modifierKeyCodes: [(CGEventFlags, CGKeyCode)] = [
        (.maskCommand, 0x37),
        (.maskShift, 0x38),
        (.maskAlternate, 0x3A),
        (.maskControl, 0x3B),
        (.maskAlphaShift, 0x39)
    ]

    static func flag(for keyCode: CGKeyCode?) -> CGEventFlags? {
        guard let keyCode else { return nil }
        let allModifierCodes: [(CGEventFlags, CGKeyCode)] = [
            (.maskCommand, 0x37),
            (.maskCommand, 0x36),
            (.maskShift, 0x38),
            (.maskShift, 0x3C),
            (.maskAlternate, 0x3A),
            (.maskAlternate, 0x3D),
            (.maskControl, 0x3B),
            (.maskControl, 0x3E),
            (.maskAlphaShift, 0x39)
        ]
        return allModifierCodes.first { $0.1 == keyCode }?.0
    }
}
