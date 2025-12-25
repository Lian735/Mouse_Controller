//
//  GameModeMonitor.swift
//  Mouse Controller
//
//  Created by Lian on 25.12.25.
//

import AppKit
import Foundation

@MainActor
final class GameModeMonitor: ObservableObject {
    static let shared = GameModeMonitor()

    @Published private(set) var isGameModeActive: Bool = false

    private var appObserver: NSObjectProtocol?

    private init() {}

    func start() {
        guard appObserver == nil else { return }
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    private func refresh() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            isGameModeActive = false
            return
        }
        isGameModeActive = app.isLikelyGame
    }
}

private extension NSRunningApplication {
    var isLikelyGame: Bool {
        guard let bundleURL = bundleURL, let bundle = Bundle(url: bundleURL) else {
            return false
        }
        let category = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType")
        let secondary = bundle.object(forInfoDictionaryKey: "LSApplicationSecondaryCategoryType")
        return isGameCategory(category) || isGameCategory(secondary)
    }

    func isGameCategory(_ value: Any?) -> Bool {
        if let category = value as? String {
            return category.localizedCaseInsensitiveContains("games")
        }
        if let categories = value as? [String] {
            return categories.contains { $0.localizedCaseInsensitiveContains("games") }
        }
        return false
    }
}
