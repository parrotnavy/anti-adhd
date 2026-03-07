import AppKit
import ApplicationServices

protocol AccessibilityServicing: AnyObject {
    var isTrusted: Bool { get }

    @discardableResult
    func requestPermission() -> Bool

    func focusedWindowTarget() -> WindowTarget?
    func frame(of window: AXUIElement) -> CGRect?
    func activeScreenByMouse() -> NSScreen?
}

final class AccessibilityService: AccessibilityServicing {
    private let trustedCheckOptionPromptKey = "AXTrustedCheckOptionPrompt"
    private let systemWide = AXUIElementCreateSystemWide()
    private let promptCooldown: TimeInterval
    private var lastPromptDate: Date?
    private let trustedCheck: () -> Bool
    private let trustedCheckWithOptions: (CFDictionary) -> Bool
    private let now: () -> Date

    init(
        promptCooldown: TimeInterval = 2.0,
        trustedCheck: @escaping () -> Bool = { AXIsProcessTrusted() },
        trustedCheckWithOptions: @escaping (CFDictionary) -> Bool = { AXIsProcessTrustedWithOptions($0) },
        now: @escaping () -> Date = Date.init
    ) {
        self.promptCooldown = max(promptCooldown, 0)
        self.trustedCheck = trustedCheck
        self.trustedCheckWithOptions = trustedCheckWithOptions
        self.now = now
    }

    var isTrusted: Bool {
        trustedCheck()
    }

    @discardableResult
    func requestPermission() -> Bool {
        if isTrusted {
            return true
        }

        guard canPromptNow() else {
            return false
        }

        lastPromptDate = now()
        let options = [trustedCheckOptionPromptKey: true] as CFDictionary
        return trustedCheckWithOptions(options)
    }

    func hasPermission(prompt: Bool = false) -> Bool {
        prompt ? requestPermission() : isTrusted
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

    private func canPromptNow() -> Bool {
        guard let lastPromptDate else {
            return true
        }

        return now().timeIntervalSince(lastPromptDate) >= promptCooldown
    }
}
