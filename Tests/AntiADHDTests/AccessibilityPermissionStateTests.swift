@testable import AntiADHD
import AppKit
import ApplicationServices
import XCTest

private final class MockAccessibilityService: AccessibilityServicing {
    var isTrusted: Bool

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func requestPermission() -> Bool {
        isTrusted
    }

    func focusedWindowTarget() -> WindowTarget? {
        nil
    }

    func frame(of window: AXUIElement) -> CGRect? {
        nil
    }

    func activeScreenByMouse() -> NSScreen? {
        nil
    }
}

final class AccessibilityPermissionStateTests: XCTestCase {
    func testPermissionMenuStateDisablesWindowModeControlsWhenPermissionMissing() {
        let state = AccessibilityPermissionMenuState(isGranted: false)

        XCTAssertEqual(state.permissionStatusTitle, "Accessibility: Needed for window modes")
        XCTAssertTrue(state.requestPermissionEnabled)
        XCTAssertFalse(state.focusedWindowModeEnabled)
        XCTAssertFalse(state.lockedWindowModeEnabled)
        XCTAssertFalse(state.lockCurrentWindowEnabled)
    }

    func testPermissionMenuStateEnablesWindowModeControlsWhenPermissionGranted() {
        let state = AccessibilityPermissionMenuState(isGranted: true)

        XCTAssertEqual(state.permissionStatusTitle, "Accessibility: Granted")
        XCTAssertFalse(state.requestPermissionEnabled)
        XCTAssertTrue(state.focusedWindowModeEnabled)
        XCTAssertTrue(state.lockedWindowModeEnabled)
        XCTAssertTrue(state.lockCurrentWindowEnabled)
    }

    @MainActor
    func testCoordinatorRefreshesPermissionControlledMenuStateAfterAppReactivation() {
        let accessibilityService = MockAccessibilityService(isTrusted: false)
        let coordinator = AppCoordinator(
            accessibilityService: accessibilityService,
            notificationCenter: NotificationCenter(),
            automaticUpdateChecksProvider: { true }
        )

        coordinator.syncAccessibilityPermissionStateForTesting()
        XCTAssertEqual(
            coordinator.permissionMenuSnapshotForTesting(),
            expectedMenuSnapshot(isGranted: false)
        )

        accessibilityService.isTrusted = true
        coordinator.simulateApplicationDidBecomeActiveForTesting()

        XCTAssertEqual(
            coordinator.permissionMenuSnapshotForTesting(),
            expectedMenuSnapshot(isGranted: true)
        )

        coordinator.stop()
    }

    private func expectedMenuSnapshot(isGranted: Bool) -> AccessibilityPermissionMenuSnapshot {
        let state = AccessibilityPermissionMenuState(isGranted: isGranted)

        return AccessibilityPermissionMenuSnapshot(
            permissionStatusTitle: state.permissionStatusTitle,
            requestPermissionEnabled: state.requestPermissionEnabled,
            focusedWindowModeEnabled: state.focusedWindowModeEnabled,
            lockedWindowModeEnabled: state.lockedWindowModeEnabled,
            lockCurrentWindowEnabled: state.lockCurrentWindowEnabled
        )
    }
}
