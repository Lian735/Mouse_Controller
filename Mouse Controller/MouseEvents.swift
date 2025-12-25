//
//  MouseEvents.swift
//  Mouse Controller
//
//  Created by Lian on 25.12.25.
//


import Cocoa
import ApplicationServices

enum MouseEvents {
    // Track button state to send proper drag events while a button is held
    private static var isLeftDown = false
    private static var isRightDown = false
    private static var isMiddleDown = false

    // Use a dedicated event source to reduce suppression and behave like HID
    private static let source: CGEventSource? = {
        guard let s = CGEventSource(stateID: .hidSystemState) else { return nil }
        s.localEventsSuppressionInterval = 0.0
        // Permit all local events during suppression windows to avoid conflicts with remote events
        s.setLocalEventsFilterDuringSuppressionState(CGEventFilterMask(rawValue: UInt32.max), state: .eventSuppressionStateSuppressionInterval)
        s.setLocalEventsFilterDuringSuppressionState(CGEventFilterMask(rawValue: UInt32.max), state: .eventSuppressionStateRemoteMouseDrag)
        return s
    }()

    static func location() -> CGPoint {
        CGEvent(source: source)?.location ?? NSEvent.mouseLocation
    }

    static func desktopBounds() -> CGRect {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        let capacity = Int(count)
        var displays = [CGDirectDisplayID](repeating: 0, count: capacity)
        CGGetActiveDisplayList(count, &displays, &count)

        var unionRect = CGRect.null
        for id in displays {
            unionRect = unionRect.union(CGDisplayBounds(id))
        }
        return unionRect
    }

    static func moveBy(dx: CGFloat, dy: CGFloat) {
        var p = location()
        // CGEvent coordinates have origin at the top-left; invert Y for "up" movement
        p.x += dx
        p.y -= dy

        moveTo(p)
    }

    static func moveTo(_ point: CGPoint) {
        var p = point

        let b = desktopBounds()
        p.x = min(max(p.x, b.minX), b.maxX)
        p.y = min(max(p.y, b.minY), b.maxY)

        let type: CGEventType
        let button: CGMouseButton
        if isLeftDown {
            type = .leftMouseDragged
            button = .left
        } else if isRightDown {
            type = .rightMouseDragged
            button = .right
        } else if isMiddleDown {
            type = .otherMouseDragged
            button = .center
        } else {
            type = .mouseMoved
            button = .left
        }

        guard let e = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: p, mouseButton: button) else { return }
        e.post(tap: .cghidEventTap)
    }

    static func leftDown() { isLeftDown = true; mouse(.leftMouseDown, .left) }
    static func leftUp()   { isLeftDown = false; mouse(.leftMouseUp, .left) }
    static func rightDown(){ isRightDown = true; mouse(.rightMouseDown, .right) }
    static func rightUp()  { isRightDown = false; mouse(.rightMouseUp, .right) }
    static func middleDown() { isMiddleDown = true; mouse(.otherMouseDown, .center) }
    static func middleUp() { isMiddleDown = false; mouse(.otherMouseUp, .center) }

    static func scroll(dx: Int32, dy: Int32) {
        guard let e = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0) else { return }
        e.post(tap: .cghidEventTap)
    }

    private static func mouse(_ type: CGEventType, _ button: CGMouseButton) {
        let p = location()
        guard let e = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: p, mouseButton: button) else { return }
        e.post(tap: .cghidEventTap)
    }
}
