import SwiftUI
import ApplicationServices

struct ShortcutRecorderView: View {
    @Binding var recorded: Shortcut?
    @State private var isRecording = false
    @StateObject private var recordingState = ShortcutRecordingState.shared
    @StateObject private var recorder = ShortcutEventRecorder()

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
        recordingState.isRecording = true
        recorder.onShortcutRecorded = { shortcut in
            recorded = shortcut
        }
        recorder.onRecordingStopped = {
            isRecording = false
        }
        recorder.start()
    }

    private func stopCapture() {
        recorder.stop()
        recordingState.isRecording = false
    }
}

private final class ShortcutEventRecorder: ObservableObject {
    var onShortcutRecorded: ((Shortcut) -> Void)?
    var onRecordingStopped: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressedKeys = Set<CGKeyCode>()
    private var lastModifiers: CGEventFlags = []
    private var recordedShortcut: KeyboardShortcut?
    private var hasPrimaryKey = false

    func start() {
        resetState()
        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let recorder = Unmanaged<ShortcutEventRecorder>.fromOpaque(refcon).takeUnretainedValue()
            return recorder.handleEvent(type: type, event: event)
        }

        guard let tap = CGEventTapCreate(
            .cgSessionEventTap,
            .headInsertEventTap,
            .defaultTap,
            CGEventMask(mask),
            callback,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            onRecordingStopped?()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEventTapEnable(tap, true)
        }
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
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
        lastModifiers = []
        recordedShortcut = nil
        hasPrimaryKey = false
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .leftMouseDown:
            recordMouse(.left)
            return nil
        case .rightMouseDown:
            recordMouse(.right)
            return nil
        case .otherMouseDown:
            recordMouse(.middle)
            return nil
        case .flagsChanged:
            handleFlagsChanged(event)
            return nil
        case .keyDown:
            handleKeyDown(event)
            return nil
        case .keyUp:
            handleKeyUp(event)
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func recordMouse(_ button: MouseButton) {
        DispatchQueue.main.async { [onShortcutRecorded, onRecordingStopped] in
            onShortcutRecorded?(.mouse(button))
            onRecordingStopped?()
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let filtered = filteredModifiers(from: event.flags)
        lastModifiers = filtered

        if let flag = modifierFlag(for: keyCode) {
            if filtered.contains(flag) {
                pressedKeys.insert(keyCode)
                if !hasPrimaryKey {
                    recordedShortcut = KeyboardShortcut(keyCode: keyCode, modifiers: [])
                }
            } else {
                pressedKeys.remove(keyCode)
            }
        }
        finalizeIfIdle()
    }

    private func handleKeyDown(_ event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        if modifierFlag(for: keyCode) != nil {
            return
        }
        pressedKeys.insert(keyCode)
        hasPrimaryKey = true
        recordedShortcut = KeyboardShortcut(keyCode: keyCode, modifiers: lastModifiers)
    }

    private func handleKeyUp(_ event: CGEvent) {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        pressedKeys.remove(keyCode)
        finalizeIfIdle()
    }

    private func finalizeIfIdle() {
        guard pressedKeys.isEmpty, let shortcut = recordedShortcut else { return }
        DispatchQueue.main.async { [onShortcutRecorded, onRecordingStopped] in
            onShortcutRecorded?(.keyboard(shortcut))
            onRecordingStopped?()
        }
    }

    private func filteredModifiers(from flags: CGEventFlags) -> CGEventFlags {
        flags.intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
    }

    private func modifierFlag(for keyCode: CGKeyCode) -> CGEventFlags? {
        switch keyCode {
        case 0x37, 0x36:
            return .maskCommand
        case 0x38, 0x3C:
            return .maskShift
        case 0x3A, 0x3D:
            return .maskAlternate
        case 0x3B, 0x3E:
            return .maskControl
        default:
            return nil
        }
    }
}
