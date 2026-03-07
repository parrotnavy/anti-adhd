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

    func testHasPermissionPromptSkipsPromptWhenAlreadyTrusted() {
        var trustedChecks = 0
        var promptedChecks = 0

        let service = AccessibilityService(
            trustedCheck: {
                trustedChecks += 1
                return true
            },
            trustedCheckWithOptions: { _ in
                promptedChecks += 1
                return true
            }
        )

        XCTAssertTrue(service.hasPermission(prompt: true))
        XCTAssertEqual(trustedChecks, 1)
        XCTAssertEqual(promptedChecks, 0)
    }

    func testIsTrustedCheckDoesNotTriggerPrompt() {
        var trustedChecks = 0
        var promptedChecks = 0

        let service = AccessibilityService(
            trustedCheck: {
                trustedChecks += 1
                return false
            },
            trustedCheckWithOptions: { _ in
                promptedChecks += 1
                return false
            }
        )

        XCTAssertFalse(service.isTrusted)
        XCTAssertEqual(trustedChecks, 1)
        XCTAssertEqual(promptedChecks, 0)

        XCTAssertFalse(service.hasPermission())
        XCTAssertEqual(trustedChecks, 2)
        XCTAssertEqual(promptedChecks, 0)
    }

    func testHasPermissionPromptIsRateLimited() {
        var promptedChecks = 0
        var currentTime = Date(timeIntervalSince1970: 100)

        let service = AccessibilityService(
            promptCooldown: 2.0,
            trustedCheck: { false },
            trustedCheckWithOptions: { _ in
                promptedChecks += 1
                return false
            },
            now: { currentTime }
        )

        XCTAssertFalse(service.hasPermission(prompt: true))
        XCTAssertEqual(promptedChecks, 1)

        XCTAssertFalse(service.hasPermission(prompt: true))
        XCTAssertEqual(promptedChecks, 1)

        currentTime = Date(timeIntervalSince1970: 103)
        XCTAssertFalse(service.hasPermission(prompt: true))
        XCTAssertEqual(promptedChecks, 2)
    }

    func testRequestPermissionUpdatesFutureReadOnlyChecksAfterGrant() {
        var promptedChecks = 0
        var isGranted = false

        let service = AccessibilityService(
            trustedCheck: { isGranted },
            trustedCheckWithOptions: { _ in
                promptedChecks += 1
                isGranted = true
                return true
            }
        )

        XCTAssertFalse(service.isTrusted)
        XCTAssertTrue(service.requestPermission())
        XCTAssertEqual(promptedChecks, 1)
        XCTAssertTrue(service.isTrusted)
        XCTAssertTrue(service.hasPermission())
    }
}
