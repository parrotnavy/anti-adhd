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
