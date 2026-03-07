import AppKit
import ApplicationServices

enum OverlayMode: String, CaseIterable {
    case currentDisplay
    case focusedWindow
    case lockedWindow

    var menuTitle: String {
        switch self {
        case .currentDisplay:
            return "Current Display"
        case .focusedWindow:
            return "Focused Window"
        case .lockedWindow:
            return "Locked Window"
        }
    }
}

enum FocusedWindowBackdropStyle: String, CaseIterable {
    case frozenFrame
    case blackOverlay
    case blurOverlay

    var menuTitle: String {
        switch self {
        case .frozenFrame:
            return "Freeze Non-selected Area"
        case .blackOverlay:
            return "Black Overlay"
        case .blurOverlay:
            return "Blur Non-selected Area"
        }
    }
}

struct WindowTarget {
    let element: AXUIElement
    let pid: pid_t
    let appName: String?
    var frame: CGRect
}

enum HotKeyAction: UInt32 {
    case toggleOverlay = 1
    case lockWindow = 2
    case emergencyOff = 3
}

struct AccessibilityPermissionMenuState: Equatable {
    let isGranted: Bool

    var permissionStatusTitle: String {
        isGranted ? "Accessibility: Granted" : "Accessibility: Needed for window modes"
    }

    var requestPermissionEnabled: Bool {
        !isGranted
    }

    var focusedWindowModeEnabled: Bool {
        isGranted
    }

    var lockedWindowModeEnabled: Bool {
        isGranted
    }

    var lockCurrentWindowEnabled: Bool {
        isGranted
    }
}

struct AccessibilityPermissionMenuSnapshot: Equatable {
    let permissionStatusTitle: String
    let requestPermissionEnabled: Bool
    let focusedWindowModeEnabled: Bool
    let lockedWindowModeEnabled: Bool
    let lockCurrentWindowEnabled: Bool
}
