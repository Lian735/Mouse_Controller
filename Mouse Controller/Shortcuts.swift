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

@MainActor
final class ShortcutStore: ObservableObject {
    static let shared = ShortcutStore()
    private init() { load() }

    @Published var bindings: [ControllerButton: Shortcut] = [:] { didSet { save() } }

    private let d = UserDefaults.standard
    private let k = "ControllerMouseShortcuts"

    private func load() {
        guard let data = d.data(forKey: k) else { return }
        if let decoded = try? JSONDecoder().decode([ControllerButton: Shortcut].self, from: data) {
            bindings = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bindings) {
            d.set(data, forKey: k)
        }
    }

    func set(_ shortcut: Shortcut?, for button: ControllerButton) {
        if let s = shortcut { bindings[button] = s } else { bindings.removeValue(forKey: button) }
    }

    func shortcut(for button: ControllerButton) -> Shortcut? { bindings[button] }

    func reset() {
        bindings.removeAll()
        d.removeObject(forKey: k)
        objectWillChange.send()
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
        // Press modifiers
        let mods: [(CGEventFlags, CGKeyCode)] = [
            (.maskCommand, 0x37), // Command
            (.maskShift,   0x38), // Shift
            (.maskAlternate, 0x3A), // Option
            (.maskControl, 0x3B) // Control
        ]
        for (flag, code) in mods where ks.modifiers.contains(flag) {
            if let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true) { e.flags = flag; e.post(tap: .cghidEventTap) }
            else {
                #if DEBUG
                print("Failed to create key down for modifier: \(flag)")
                #endif
            }
        }
        // Key down/up
        if let down = CGEvent(keyboardEventSource: src, virtualKey: ks.keyCode, keyDown: true) {
            down.flags = ks.modifiers
            down.post(tap: .cghidEventTap)
        } else {
            #if DEBUG
            print("Failed to create key down for keyCode: \(ks.keyCode)")
            #endif
        }
        if let up = CGEvent(keyboardEventSource: src, virtualKey: ks.keyCode, keyDown: false) {
            up.flags = ks.modifiers
            up.post(tap: .cghidEventTap)
        } else {
            #if DEBUG
            print("Failed to create key up for keyCode: \(ks.keyCode)")
            #endif
        }
        // Release modifiers
        for (flag, code) in mods.reversed() where ks.modifiers.contains(flag) {
            if let e = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false) { e.flags = flag; e.post(tap: .cghidEventTap) }
            else {
                #if DEBUG
                print("Failed to create key up for modifier: \(flag)")
                #endif
            }
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
        case 0x08: return "C"
        case 0x00: return "A"
        case 0x0B: return "B"
        case 0x0C: return "="
        default: return String(format: "0x%02X", keyCode)
        }
    }
}

