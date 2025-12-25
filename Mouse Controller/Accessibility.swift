//
//  Accessibility.swift
//  Mouse Controller
//
//  Created by Lian on 25.12.25.
//

import ApplicationServices

enum Accessibility {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestPromptIfNeeded() {
        guard !isTrusted else { return }
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func slowdownFactorNearPointer() -> CGFloat {
        return 1.0
    }

    // MARK: - Private helpers

    private static func slowdownFactor(for element: AXUIElement) -> CGFloat? {
        // Fetch role and subrole to detect controls
        guard let role: String = copyAttribute(element, kAXRoleAttribute as CFString), !role.isEmpty else { return nil }
        let subrole: String? = copyAttribute(element, kAXSubroleAttribute as CFString)

        // Common actionable roles
        let actionableRoles: Set<String> = [
            kAXButtonRole as String,
            kAXCheckBoxRole as String,
            kAXRadioButtonRole as String,
            kAXPopUpButtonRole as String,
            kAXMenuItemRole as String,
            kAXTabGroupRole as String,
            kAXTextFieldRole as String,
            "AXLink",
            kAXDisclosureTriangleRole as String
        ]

        // Consider table/collection cells clickable
        let containerRoles: Set<String> = [
            kAXTableRole as String,
            kAXOutlineRole as String,
            "AXCollectionView",
            kAXListRole as String
        ]

        if actionableRoles.contains(role) { return 0.35 }
        if containerRoles.contains(role) { return 0.6 }

        // Special subroles like close/minimize/zoom buttons
        if let sub = subrole, [kAXCloseButtonSubrole as String, kAXMinimizeButtonSubrole as String, kAXZoomButtonSubrole as String].contains(sub) {
            return 0.35
        }

        // If element has a press action, also slow
        var actionNamesCF: CFArray? = nil
        if AXUIElementCopyActionNames(element, &actionNamesCF) == .success,
           let actionNames = actionNamesCF as? [String],
           actionNames.contains(kAXPressAction as String) {
            return 0.5
        }

        // If the element is a text insertion target
        if role == (kAXTextAreaRole as String) || role == (kAXTextFieldRole as String) { return 0.5 }

        return nil
    }

    private static func copyAttribute<T>(_ element: AXUIElement, _ attr: CFString) -> T? {
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, attr, &value)
        guard err == .success, let v = value else { return nil }
        return v as? T
    }
}

