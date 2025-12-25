import SwiftUI
import ApplicationServices

final class ShortcutRecorderEventTap {
    private let handler: (CGEventType, CGEvent) -> Unmanaged<CGEvent>?
    private(set) var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(handler: @escaping (CGEventType, CGEvent) -> Unmanaged<CGEvent>?) {
        self.handler = handler
        installTap()
    }

    func enable() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func installTap() {
        let mask = CGEventMask(
            (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
        )

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let tap = Unmanaged<ShortcutRecorderEventTap>.fromOpaque(refcon).takeUnretainedValue()
            return tap.handler(type, event) ?? Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }
}

struct ShortcutRecorderView: View {
    @Binding var recorded: Shortcut?
    @State private var isRecording = false
    @State private var modifiers: CGEventFlags = []
    @State private var pressedKeys: Set<CGKeyCode> = []
    @State private var pendingShortcut: KeyboardShortcut?
    @State private var eventTap: ShortcutRecorderEventTap?
    @StateObject private var recordingState = ShortcutRecordingState.shared

    var body: some View {
        HStack {
            if isRecording {
                Text(recorded?.description ?? "None")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).stroke(.secondary))
            }

            Button(isRecording ? "Stop" : "Record") {
                isRecording.toggle()
            }
            .keyboardShortcut(.defaultAction)
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue { startCapture() } else { stopCapture() }
        }
    }

    private func startCapture() {
        modifiers = []
        pressedKeys = []
        pendingShortcut = nil
        recordingState.isRecording = true
        eventTap = ShortcutRecorderEventTap { type, event in
            handleEvent(type: type, event: event)
        }
    }

    private func stopCapture() {
        eventTap?.stop()
        eventTap = nil
        recordingState.isRecording = false
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.async {
                eventTap?.enable()
            }
            return nil
        }

        DispatchQueue.main.async {
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            switch type {
            case .flagsChanged:
                modifiers = filteredModifiers(event.flags)
                if pressedKeys.isEmpty {
                    if modifiers.isEmpty {
                        finalizeIfReady()
                    } else if isModifierKey(keyCode) {
                        pendingShortcut = KeyboardShortcut(keyCode: keyCode, modifiers: [])
                    }
                }
            case .keyDown:
                if !isModifierKey(keyCode) {
                    pressedKeys.insert(keyCode)
                    pendingShortcut = KeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
                }
            case .keyUp:
                pressedKeys.remove(keyCode)
                if pressedKeys.isEmpty && modifiers.isEmpty {
                    finalizeIfReady()
                }
            case .leftMouseDown:
                recorded = .mouse(.left)
                isRecording = false
            case .rightMouseDown:
                recorded = .mouse(.right)
                isRecording = false
            case .otherMouseDown:
                recorded = .mouse(.middle)
                isRecording = false
            default:
                break
            }
        }

        return nil
    }

    private func finalizeIfReady() {
        if let pendingShortcut {
            recorded = .keyboard(pendingShortcut)
            isRecording = false
        }
    }

    private func filteredModifiers(_ flags: CGEventFlags) -> CGEventFlags {
        flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
    }

    private func isModifierKey(_ keyCode: CGKeyCode) -> Bool {
        switch keyCode {
        case 0x37, 0x36, 0x38, 0x3C, 0x3A, 0x3D, 0x3B, 0x3E:
            return true
        default:
            return false
        }
    }
}
