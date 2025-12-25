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
            switch capture {
            case .keyboard(let shortcut):
                recorded = .keyboard(shortcut)
            case .mouse(let button):
                recorded = .mouse(button)
            }
            isRecording = false
        }
        recorder.start()
    }

    private func stopCapture() {
        recorder.stop()
        recordingState.isRecording = false
    }
}
