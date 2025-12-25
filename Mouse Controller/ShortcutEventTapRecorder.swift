import Foundation
import ApplicationServices
import AppKit
import IOKit.hidsystem

final class ShortcutEventTapRecorder {
    enum Capture {
        case keyboard(KeyboardShortcut)
        case mouse(MouseButton)
    }

    var onCapture: ((Capture) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressedKeys: Set<CGKeyCode> = []
    private var pressedModifiers: Set<CGKeyCode> = []
    private var pressedSystemKeys: Set<Int32> = []
    private var pendingShortcut: KeyboardShortcut?
    private var hasCaptured = false

    func start() {
        guard eventTap == nil else { return }
        resetState()

        let systemDefinedType = CGEventType(rawValue: 14)!
        var mask: CGEventMask = 0
        mask |= (1 << CGEventType.keyDown.rawValue)
        mask |= (1 << CGEventType.keyUp.rawValue)
        mask |= (1 << CGEventType.flagsChanged.rawValue)
        mask |= (1 << systemDefinedType.rawValue)
        mask |= (1 << CGEventType.leftMouseDown.rawValue)
        mask |= (1 << CGEventType.rightMouseDown.rawValue)
        mask |= (1 << CGEventType.otherMouseDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let recorder = Unmanaged<ShortcutEventTapRecorder>.fromOpaque(refcon).takeUnretainedValue()
            return recorder.handleEvent(proxy: proxy, type: type, event: event)
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        )

        guard let eventTap else {
            #if DEBUG
            print("Failed to create event tap for shortcut recording.")
            #endif
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        resetState()
    }

    private func resetState() {
        pressedKeys.removeAll()
        pressedModifiers.removeAll()
        pressedSystemKeys.removeAll()
        pendingShortcut = nil
        hasCaptured = false
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let systemDefinedType = CGEventType(rawValue: 14)!

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if hasCaptured {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .leftMouseDown:
            finalizeCapture(.mouse(.left))
            return nil
        case .rightMouseDown:
            finalizeCapture(.mouse(.right))
            return nil
        case .otherMouseDown:
            finalizeCapture(.mouse(.middle))
            return nil
        case .keyDown:
            handleKeyDown(event)
            return nil
        case .keyUp:
            handleKeyUp(event)
            return nil
        case .flagsChanged:
            handleFlagsChanged(event)
            return nil
        case _ where type.rawValue == systemDefinedType.rawValue:
            handleSystemDefined(event)
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleKeyDown(_ event: CGEvent) {
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 { return }
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        pressedKeys.insert(keyCode)
        pendingShortcut = KeyboardShortcut(keyCode: keyCode, modifiers: event.flags)
    }

    private func handleKeyUp(_ event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        pressedKeys.remove(keyCode)
        finalizeIfIdle()
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard let flag = ModifierKeyMapping.flag(for: keyCode) else { return }
        if event.flags.contains(flag) {
            pressedModifiers.insert(keyCode)
        } else {
            pressedModifiers.remove(keyCode)
        }
        pendingShortcut = KeyboardShortcut(keyCode: keyCode, modifiers: event.flags)
        finalizeIfIdle()
    }

    private func handleSystemDefined(_ event: CGEvent) {
        guard let info = systemKeyInfo(from: event) else { return }
        if info.isDown {
            pressedSystemKeys.insert(info.key)
            pendingShortcut = KeyboardShortcut(systemKey: info.key, modifiers: event.flags)
        } else if info.isUp {
            pressedSystemKeys.remove(info.key)
            finalizeIfIdle()
        }
    }

    private func finalizeIfIdle() {
        guard pressedKeys.isEmpty, pressedModifiers.isEmpty, pressedSystemKeys.isEmpty,
              let pendingShortcut else { return }
        finalizeCapture(.keyboard(pendingShortcut))
    }

    private func finalizeCapture(_ capture: Capture) {
        hasCaptured = true
        pendingShortcut = nil
        pressedKeys.removeAll()
        pressedModifiers.removeAll()
        pressedSystemKeys.removeAll()
        DispatchQueue.main.async { [weak self] in
            self?.onCapture?(capture)
        }
    }

    private func systemKeyInfo(from event: CGEvent) -> (key: Int32, isDown: Bool, isUp: Bool)? {
        guard let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == NX_SUBTYPE_AUX_CONTROL_BUTTONS else { return nil }
        let data1 = nsEvent.data1
        let key = Int32((data1 & 0xFFFF0000) >> 16)
        let keyState = (data1 & 0xFF00) >> 8
        let isDown = keyState == 0xA
        let isUp = keyState == 0xB
        return (key, isDown, isUp)
    }
}
