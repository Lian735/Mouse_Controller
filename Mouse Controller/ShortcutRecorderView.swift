import SwiftUI
import ApplicationServices

struct ShortcutRecorderView: View {
    @Binding var recorded: Shortcut?
    @State private var isRecording = false
    @State private var modifiers: CGEventFlags = []
    @State private var eventMonitor: Any?
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
        recordingState.isRecording = true
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

    private func stopCapture() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        recordingState.isRecording = false
    }
}
