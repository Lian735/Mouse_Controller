import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var recorded: Shortcut?
    @State private var isRecording = false
    @State private var recorder = ShortcutEventTapRecorder()
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
        recordingState.isRecording = true
        recorder.onCapture = { capture in
            // Ignore late events if recording has been stopped
            guard recordingState.isRecording else { return }
            
            Task { @MainActor in
                // Double-check state on main actor as well
                guard recordingState.isRecording else { return }
                
                switch capture {
                case .keyboard(let shortcut):
                    recorded = .keyboard(shortcut)
                case .mouse(let button):
                    recorded = .mouse(button)
                }
                
                // Stop after first successful capture
                isRecording = false
            }
        }
        recorder.start()
    }
    
    private func stopCapture() {
        // Prevent further handling before stopping the tap
        recordingState.isRecording = false
        recorder.onCapture = nil
        recorder.stop()
    }
}
