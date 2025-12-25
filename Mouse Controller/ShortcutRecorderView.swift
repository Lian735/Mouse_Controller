import SwiftUI
import ApplicationServices
import AppKit

struct ShortcutRecorderView: View {
    @Binding var recorded: Shortcut?
    @State private var isRecording = false
    @State private var modifiers: CGEventFlags = []
    @State private var eventMonitor: Any?
    @State private var eventTap: ShortcutEventTap?
    @State private var pressedKeyCodes: Set<CGKeyCode> = []
    @State private var capturedKeyCode: CGKeyCode?
    @State private var capturedModifiers: CGEventFlags = []
    @State private var pendingModifierOnlyFlags: CGEventFlags?
    @State private var capturedSystemKeyCode: Int32?
    @State private var systemKeyIsDown = false
    @State private var capturedSystemModifiers: CGEventFlags = []
    @StateObject private var recordingState = ShortcutRecordingState.shared
    private let modifierMask: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl, .maskFunction]

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
        pressedKeyCodes.removeAll()
        capturedKeyCode = nil
        capturedModifiers = []
        pendingModifierOnlyFlags = nil
        capturedSystemKeyCode = nil
        systemKeyIsDown = false
        capturedSystemModifiers = []
        recordingState.isRecording = true
        eventTap = ShortcutEventTap(mask: ShortcutEventTap.recordingMask) { event, type in
            handleEvent(event: event, type: type)
        }
        if eventTap?.start() != true {
            eventTap = nil
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { event in
                if event.type == .flagsChanged {
                    modifiers = event.cgEvent?.flags ?? []
                    return nil
                }
                if event.type == .keyDown, let cg = event.cgEvent {
                    let keyCode = cg.getIntegerValueField(.keyboardEventKeycode)
                    recorded = .keyboard(KeyboardShortcut(keyCode: CGKeyCode(keyCode), modifiers: modifiers))
                    isRecording = false
                    return nil
                }
                if event.type == .keyUp {
                    return nil
                }
                if event.type == .leftMouseDown { recorded = .mouse(.left); isRecording = false; return nil }
                if event.type == .rightMouseDown { recorded = .mouse(.right); isRecording = false; return nil }
                if event.type == .otherMouseDown { recorded = .mouse(.middle); isRecording = false; return nil }
                return event
            }
        }
    }

    private func stopCapture() {
        eventTap?.stop()
        eventTap = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        recordingState.isRecording = false
    }

    private func handleEvent(event: CGEvent, type: CGEventType) -> CGEvent? {
        switch type {
        case .flagsChanged:
            handleFlagsChanged(event: event)
            return nil
        case .keyDown:
            handleKeyDown(event: event)
            return nil
        case .keyUp:
            handleKeyUp(event: event)
            return nil
        case .systemDefined:
            handleSystemDefined(event: event)
            return nil
        case .leftMouseDown:
            DispatchQueue.main.async {
                recorded = .mouse(.left)
                isRecording = false
            }
            return nil
        case .rightMouseDown:
            DispatchQueue.main.async {
                recorded = .mouse(.right)
                isRecording = false
            }
            return nil
        case .otherMouseDown:
            DispatchQueue.main.async {
                recorded = .mouse(.middle)
                isRecording = false
            }
            return nil
        default:
            return event
        }
    }

    private func handleFlagsChanged(event: CGEvent) {
        let flags = event.flags.intersection(modifierMask)
        DispatchQueue.main.async {
            modifiers = flags
        }
        if flags.isEmpty {
            if capturedKeyCode == nil && capturedSystemKeyCode == nil {
                if let pending = pendingModifierOnlyFlags, pressedKeyCodes.isEmpty {
                    DispatchQueue.main.async {
                        recorded = .keyboard(KeyboardShortcut(keyCode: KeyboardShortcut.modifierOnlyKeyCode, modifiers: pending))
                        isRecording = false
                    }
                }
                pendingModifierOnlyFlags = nil
            }
            finalizeIfNeeded(currentFlags: flags)
        } else if capturedKeyCode == nil && capturedSystemKeyCode == nil {
            pendingModifierOnlyFlags = flags
        }
    }

    private func handleKeyDown(event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection(modifierMask)
        DispatchQueue.main.async {
            modifiers = flags
        }
        pressedKeyCodes.insert(keyCode)
        if capturedKeyCode == nil && capturedSystemKeyCode == nil {
            capturedKeyCode = keyCode
            capturedModifiers = flags
            pendingModifierOnlyFlags = nil
        }
    }

    private func handleKeyUp(event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        pressedKeyCodes.remove(keyCode)
        let flags = event.flags.intersection(modifierMask)
        DispatchQueue.main.async {
            modifiers = flags
        }
        finalizeIfNeeded(currentFlags: flags)
    }

    private func handleSystemDefined(event: CGEvent) {
        guard let nsEvent = NSEvent(cgEvent: event) else { return }
        guard nsEvent.subtype.rawValue == 8 else { return }
        let data1 = nsEvent.data1
        let keyCode = Int32((data1 & 0xFFFF0000) >> 16)
        let keyState = (data1 & 0x0000FF00) >> 8
        let flags = event.flags.intersection(modifierMask)
        DispatchQueue.main.async {
            modifiers = flags
        }
        if keyState == 0x0A {
            capturedSystemKeyCode = keyCode
            systemKeyIsDown = true
            capturedSystemModifiers = flags
            pendingModifierOnlyFlags = nil
        } else if keyState == 0x0B {
            systemKeyIsDown = false
            finalizeIfNeeded(currentFlags: flags)
        }
    }

    private func finalizeIfNeeded(currentFlags: CGEventFlags) {
        guard pressedKeyCodes.isEmpty else { return }
        guard currentFlags.isEmpty else { return }
        if let keyCode = capturedKeyCode {
            DispatchQueue.main.async {
                recorded = .keyboard(KeyboardShortcut(keyCode: keyCode, modifiers: capturedModifiers))
                isRecording = false
            }
        } else if let systemKeyCode = capturedSystemKeyCode, !systemKeyIsDown {
            DispatchQueue.main.async {
                recorded = .system(SystemShortcut(keyCode: systemKeyCode, modifiers: capturedSystemModifiers))
                isRecording = false
            }
        }
        capturedKeyCode = nil
        capturedModifiers = []
        capturedSystemKeyCode = nil
        capturedSystemModifiers = []
    }
}

private final class ShortcutEventTap {
    typealias Handler = (CGEvent, CGEventType) -> CGEvent?
    static let recordingMask: CGEventMask =
        (1 << CGEventType.flagsChanged.rawValue)
        | (1 << CGEventType.keyDown.rawValue)
        | (1 << CGEventType.keyUp.rawValue)
        | (1 << CGEventType.systemDefined.rawValue)
        | (1 << CGEventType.leftMouseDown.rawValue)
        | (1 << CGEventType.rightMouseDown.rawValue)
        | (1 << CGEventType.otherMouseDown.rawValue)

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let mask: CGEventMask
    private let handler: Handler

    init(mask: CGEventMask, handler: @escaping Handler) {
        self.mask = mask
        self.handler = handler
    }

    func start() -> Bool {
        guard eventTap == nil else { return true }
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let tap = Unmanaged<ShortcutEventTap>.fromOpaque(userInfo).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                tap.enable()
                return Unmanaged.passUnretained(event)
            }
            if let processed = tap.handler(event, type) {
                return Unmanaged.passUnretained(processed)
            }
            return nil
        }
        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        eventTap = CGEventTapCreate(.cghidEventTap, .headInsertEventTap, .defaultTap, mask, callback, userInfo)
        guard let eventTap else { return false }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        enable()
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func enable() {
        if let eventTap {
            CGEventTapEnable(eventTap, true)
        }
    }
}
