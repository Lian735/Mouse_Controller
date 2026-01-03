import Foundation
import Combine

@MainActor
final class ShortcutRecordingState: ObservableObject {
    static let shared = ShortcutRecordingState()
    private init() {}

    // Indicates whether the app is currently recording a keyboard/mouse shortcut.
    // Controller input should be ignored while this is true.
    @Published var isRecording: Bool = false
}
