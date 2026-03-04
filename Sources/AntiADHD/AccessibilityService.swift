import AppKit
import ApplicationServices

final class AccessibilityService {
    private let systemWide = AXUIElementCreateSystemWide()

    func hasPermission(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func focusedWindowTarget() -> WindowTarget? {
        guard let focusedApp: AXUIElement = copyAttribute(from: systemWide, attribute: kAXFocusedApplicationAttribute as CFString) else {
            return nil
        }

        var pid: pid_t = 0
        AXUIElementGetPid(focusedApp, &pid)

        guard let focusedWindow: AXUIElement = copyAttribute(from: focusedApp, attribute: kAXFocusedWindowAttribute as CFString),
              let frame = frame(of: focusedWindow) else {
            return nil
        }

        let appName = NSRunningApplication(processIdentifier: pid)?.localizedName
        return WindowTarget(element: focusedWindow, pid: pid, appName: appName, frame: frame)
    }

    func frame(of window: AXUIElement) -> CGRect? {
        guard let positionValue: AXValue = copyAttribute(from: window, attribute: kAXPositionAttribute as CFString),
              let sizeValue: AXValue = copyAttribute(from: window, attribute: kAXSizeAttribute as CFString) else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size),
              size.width > 0,
              size.height > 0 else {
            return nil
        }

        let accessibilityRect = CGRect(origin: position, size: size)
        return convertAccessibilityRectToAppKit(accessibilityRect)
    }

    func activeScreenByMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let matching = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return matching
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func copyAttribute<T>(from element: AXUIElement, attribute: CFString) -> T? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value, let typed = value as? T else {
            return nil
        }
        return typed
    }

    private func convertAccessibilityRectToAppKit(_ accessibilityRect: CGRect) -> CGRect {
        let mainScreenMaxY = NSScreen.main?.frame.maxY
            ?? NSScreen.screens.first?.frame.maxY
            ?? 0

        return Self.convertAccessibilityRectToAppKit(accessibilityRect, mainScreenMaxY: mainScreenMaxY)
    }

    static func convertAccessibilityRectToAppKit(_ accessibilityRect: CGRect, mainScreenMaxY: CGFloat) -> CGRect {
        let convertedY = mainScreenMaxY - accessibilityRect.origin.y - accessibilityRect.height

        return CGRect(
            x: accessibilityRect.origin.x,
            y: convertedY,
            width: accessibilityRect.width,
            height: accessibilityRect.height
        )
    }
}
