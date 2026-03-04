@testable import AntiADHD
import XCTest

final class AntiADHDTests: XCTestCase {
    func testOverlayModeMenuTitlesAreStable() {
        XCTAssertEqual(OverlayMode.currentDisplay.menuTitle, "Current Display")
        XCTAssertEqual(OverlayMode.focusedWindow.menuTitle, "Focused Window")
        XCTAssertEqual(OverlayMode.lockedWindow.menuTitle, "Locked Window")
    }

    func testFocusedBackdropMenuTitlesAreStable() {
        XCTAssertEqual(FocusedWindowBackdropStyle.frozenFrame.menuTitle, "Freeze Non-selected Area")
        XCTAssertEqual(FocusedWindowBackdropStyle.blackOverlay.menuTitle, "Black Overlay")
        XCTAssertEqual(FocusedWindowBackdropStyle.blurOverlay.menuTitle, "Blur Non-selected Area")
    }

    func testHotKeyActionRawValuesAreUnique() {
        XCTAssertNotEqual(HotKeyAction.toggleOverlay.rawValue, HotKeyAction.lockWindow.rawValue)
        XCTAssertNotEqual(HotKeyAction.lockWindow.rawValue, HotKeyAction.emergencyOff.rawValue)
    }

    func testAccessibilityRectConversionUsesFlippedYAxis() {
        let accessibilityRect = CGRect(x: 120, y: 180, width: 800, height: 400)
        let converted = AccessibilityService.convertAccessibilityRectToAppKit(accessibilityRect, mainScreenMaxY: 1000)

        XCTAssertEqual(converted.origin.x, 120)
        XCTAssertEqual(converted.origin.y, 420)
        XCTAssertEqual(converted.width, 800)
        XCTAssertEqual(converted.height, 400)
    }
}
