import Foundation
import ApplicationServices
import Combine

enum MouseButton: Int, Codable, CaseIterable, CustomStringConvertible {
    case left = 0
    case right = 1
    case middle = 2

    var description: String {
        switch self { case .left: return "Left Click"; case .right: return "Right Click"; case .middle: return "Middle Click" }
    }
}

struct KeyboardShortcut: Codable, Equatable {
    var keyCode: CGKeyCode
    var modifiers: CGEventFlags

    private enum CodingKeys: String, CodingKey { case keyCode, modifiers }

    init(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let keyCodeRaw = try container.decode(UInt16.self, forKey: .keyCode)
        let modifiersRaw = try container.decode(UInt64.self, forKey: .modifiers)
        self.keyCode = CGKeyCode(keyCodeRaw)
        self.modifiers = CGEventFlags(rawValue: modifiersRaw)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(UInt16(keyCode), forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
    }
}

enum Shortcut: Codable, Equatable, CustomStringConvertible {
    case keyboard(KeyboardShortcut)
    case mouse(MouseButton)

    var description: String {
        switch self {
        case .keyboard(let k):
            return ShortcutFormatter.format(modifiers: k.modifiers, keyCode: k.keyCode)
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
        keyDown(ks)
        keyUp(ks)
    }

    static func keyDown(_ ks: KeyboardShortcut) {
        guard let src = CGEventSource(stateID: .hidSystemState) else {
            #if DEBUG
            print("Failed to create CGEventSource; check Accessibility permissions.")
            #endif
            return
        }

        let modifiers = filteredModifiers(from: ks.modifiers)
        if !isModifierKey(ks.keyCode) {
            pressModifiers(modifiers, source: src)
        }

        if let down = CGEvent(keyboardEventSource: src, virtualKey: ks.keyCode, keyDown: true) {
            down.flags = modifiers
            down.post(tap: .cghidEventTap)
        } else {
            #if DEBUG
            print("Failed to create key down for keyCode: \(ks.keyCode)")
            #endif
        }
    }

    static func keyUp(_ ks: KeyboardShortcut) {
        guard let src = CGEventSource(stateID: .hidSystemState) else {
            #if DEBUG
            print("Failed to create CGEventSource; check Accessibility permissions.")
            #endif
            return
        }

        let modifiers = filteredModifiers(from: ks.modifiers)
        if let up = CGEvent(keyboardEventSource: src, virtualKey: ks.keyCode, keyDown: false) {
            up.flags = modifiers
            up.post(tap: .cghidEventTap)
        } else {
            #if DEBUG
            print("Failed to create key up for keyCode: \(ks.keyCode)")
            #endif
        }

        if !isModifierKey(ks.keyCode) {
            releaseModifiers(modifiers, source: src)
        }
    }

    private static func pressModifiers(_ modifiers: CGEventFlags, source: CGEventSource) {
        for (flag, code) in modifierKeyCodes() where modifiers.contains(flag) {
            if let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true) {
                e.flags = flag
                e.post(tap: .cghidEventTap)
            } else {
                #if DEBUG
                print("Failed to create key down for modifier: \(flag)")
                #endif
            }
        }
    }

    private static func releaseModifiers(_ modifiers: CGEventFlags, source: CGEventSource) {
        for (flag, code) in modifierKeyCodes().reversed() where modifiers.contains(flag) {
            if let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) {
                e.flags = flag
                e.post(tap: .cghidEventTap)
            } else {
                #if DEBUG
                print("Failed to create key up for modifier: \(flag)")
                #endif
            }
        }
    }

    private static func filteredModifiers(from flags: CGEventFlags) -> CGEventFlags {
        flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
    }

    private static func modifierKeyCodes() -> [(CGEventFlags, CGKeyCode)] {
        [
            (.maskCommand, 0x37), // Command (left)
            (.maskShift, 0x38), // Shift (left)
            (.maskAlternate, 0x3A), // Option (left)
            (.maskControl, 0x3B) // Control (left)
        ]
    }

    private static func isModifierKey(_ keyCode: CGKeyCode) -> Bool {
        switch keyCode {
        case 0x37, 0x36, 0x38, 0x3C, 0x3A, 0x3D, 0x3B, 0x3E:
            return true
        default:
            return false
        }
    }
}

enum ShortcutFormatter {
    static func format(modifiers: CGEventFlags, keyCode: CGKeyCode) -> String {
        var parts: [String] = []
        if modifiers.contains(.maskCommand) { parts.append("⌘") }
        if modifiers.contains(.maskShift) { parts.append("⇧") }
        if modifiers.contains(.maskAlternate) { parts.append("⌥") }
        if modifiers.contains(.maskControl) { parts.append("⌃") }
        let key = KeyCodeNames.name(for: keyCode)
        parts.append(key)
        return parts.joined()
    }
}

enum KeyCodeNames {
    static func name(for keyCode: CGKeyCode) -> String {
        // Minimal mapping; fall back to hex code
        switch keyCode {
        case 0x36, 0x37: return "Command"
        case 0x38, 0x3C: return "Shift"
        case 0x3A, 0x3D: return "Option"
        case 0x3B, 0x3E: return "Control"
        case 0x7A: return "F1"
        case 0x78: return "F2"
        case 0x63: return "F3"
        case 0x76: return "F4"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x6D: return "F10"
        case 0x67: return "F11"
        case 0x6F: return "F12"
        case 0x08: return "C"
        case 0x00: return "A"
        case 0x0B: return "B"
        case 0x0C: return "="
        default: return String(format: "0x%02X", keyCode)
        }
    }
}
