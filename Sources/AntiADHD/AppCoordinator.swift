import AppKit
import Carbon.HIToolbox
import Foundation

final class AppCoordinator: NSObject {
    private let overlayManager = OverlayManager()
    private let accessibilityService = AccessibilityService()
    private let hotKeyManager = HotKeyManager()

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    private var refreshTimer: Timer?

    private var isOverlayEnabled = false
    private var overlayMode: OverlayMode = .currentDisplay
    private var lockedTarget: WindowTarget?
    private var focusedBackdropStyle: FocusedWindowBackdropStyle = .blackOverlay
    private var focusedBlackOverlayOpacity: CGFloat = 1.0

    private let toggleMenuItem = NSMenuItem(title: "Enable Focus Mask (⌥⌘B)", action: #selector(toggleOverlayFromMenu), keyEquivalent: "")
    private let modeDisplayMenuItem = NSMenuItem(title: OverlayMode.currentDisplay.menuTitle, action: #selector(selectCurrentDisplayMode), keyEquivalent: "")
    private let modeFocusedMenuItem = NSMenuItem(title: OverlayMode.focusedWindow.menuTitle, action: #selector(selectFocusedWindowMode), keyEquivalent: "")
    private let modeLockedMenuItem = NSMenuItem(title: OverlayMode.lockedWindow.menuTitle, action: #selector(selectLockedWindowMode), keyEquivalent: "")

    private let backdropFrozenMenuItem = NSMenuItem(title: FocusedWindowBackdropStyle.frozenFrame.menuTitle, action: #selector(selectFrozenBackdrop), keyEquivalent: "")
    private let backdropBlackMenuItem = NSMenuItem(title: FocusedWindowBackdropStyle.blackOverlay.menuTitle, action: #selector(selectBlackBackdrop), keyEquivalent: "")
    private let backdropBlurMenuItem = NSMenuItem(title: FocusedWindowBackdropStyle.blurOverlay.menuTitle, action: #selector(selectBlurBackdrop), keyEquivalent: "")

    private let blackOpacity30MenuItem = NSMenuItem(title: "30%", action: #selector(selectBlackOverlayOpacity(_:)), keyEquivalent: "")
    private let blackOpacity50MenuItem = NSMenuItem(title: "50%", action: #selector(selectBlackOverlayOpacity(_:)), keyEquivalent: "")
    private let blackOpacity70MenuItem = NSMenuItem(title: "70%", action: #selector(selectBlackOverlayOpacity(_:)), keyEquivalent: "")
    private let blackOpacity85MenuItem = NSMenuItem(title: "85%", action: #selector(selectBlackOverlayOpacity(_:)), keyEquivalent: "")
    private let blackOpacity100MenuItem = NSMenuItem(title: "100%", action: #selector(selectBlackOverlayOpacity(_:)), keyEquivalent: "")

    private let lockWindowMenuItem = NSMenuItem(title: "Lock Current Window (⌥⌘L)", action: #selector(lockCurrentWindow), keyEquivalent: "")
    private let clearLockMenuItem = NSMenuItem(title: "Unlock Locked Window", action: #selector(clearLockedWindow), keyEquivalent: "")
    private let permissionStatusMenuItem = NSMenuItem(title: "Accessibility: Unknown", action: nil, keyEquivalent: "")
    private let requestPermissionMenuItem = NSMenuItem(title: "Request Accessibility Permission", action: #selector(requestAccessibilityPermission), keyEquivalent: "")
    private let hotKeyStatusMenuItem = NSMenuItem(title: "Hotkeys: Ready", action: nil, keyEquivalent: "")
    private let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")

    private lazy var blackOpacityMenuItems: [NSMenuItem] = [
        blackOpacity30MenuItem,
        blackOpacity50MenuItem,
        blackOpacity70MenuItem,
        blackOpacity85MenuItem,
        blackOpacity100MenuItem
    ]

    func start() {
        configureStatusItem()
        configureMenu()
        configureHotKeys()
        updateUIState()
    }

    func stop() {
        stopRefreshLoop()
        overlayManager.setEnabled(false)
    }

    private func configureStatusItem() {
        statusItem.button?.title = "○ Focus"
        statusItem.button?.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusItem.menu = menu
    }

    private func configureMenu() {
        toggleMenuItem.target = self

        modeDisplayMenuItem.target = self
        modeFocusedMenuItem.target = self
        modeLockedMenuItem.target = self

        backdropFrozenMenuItem.target = self
        backdropBlackMenuItem.target = self
        backdropBlurMenuItem.target = self

        blackOpacity30MenuItem.target = self
        blackOpacity30MenuItem.tag = 30
        blackOpacity50MenuItem.target = self
        blackOpacity50MenuItem.tag = 50
        blackOpacity70MenuItem.target = self
        blackOpacity70MenuItem.tag = 70
        blackOpacity85MenuItem.target = self
        blackOpacity85MenuItem.tag = 85
        blackOpacity100MenuItem.target = self
        blackOpacity100MenuItem.tag = 100

        lockWindowMenuItem.target = self
        clearLockMenuItem.target = self
        clearLockMenuItem.isEnabled = false

        permissionStatusMenuItem.isEnabled = false

        requestPermissionMenuItem.target = self

        hotKeyStatusMenuItem.isEnabled = false

        quitMenuItem.target = self

        let modeRootMenuItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        let modeSubMenu = NSMenu(title: "Mode")
        modeSubMenu.addItem(modeDisplayMenuItem)
        modeSubMenu.addItem(modeFocusedMenuItem)
        modeSubMenu.addItem(modeLockedMenuItem)
        modeRootMenuItem.submenu = modeSubMenu

        let focusedBackdropRootMenuItem = NSMenuItem(title: "Focused Window: Other Areas", action: nil, keyEquivalent: "")
        let focusedBackdropSubMenu = NSMenu(title: "Focused Window: Other Areas")
        focusedBackdropSubMenu.addItem(backdropFrozenMenuItem)
        focusedBackdropSubMenu.addItem(backdropBlackMenuItem)
        focusedBackdropSubMenu.addItem(backdropBlurMenuItem)
        focusedBackdropRootMenuItem.submenu = focusedBackdropSubMenu

        let blackOpacityRootMenuItem = NSMenuItem(title: "Black Overlay Opacity", action: nil, keyEquivalent: "")
        let blackOpacitySubMenu = NSMenu(title: "Black Overlay Opacity")
        blackOpacityMenuItems.forEach { blackOpacitySubMenu.addItem($0) }
        blackOpacityRootMenuItem.submenu = blackOpacitySubMenu

        menu.addItem(toggleMenuItem)
        menu.addItem(.separator())
        menu.addItem(modeRootMenuItem)
        menu.addItem(focusedBackdropRootMenuItem)
        menu.addItem(blackOpacityRootMenuItem)
        menu.addItem(.separator())
        menu.addItem(lockWindowMenuItem)
        menu.addItem(clearLockMenuItem)
        menu.addItem(.separator())
        menu.addItem(permissionStatusMenuItem)
        menu.addItem(requestPermissionMenuItem)
        menu.addItem(hotKeyStatusMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitMenuItem)
    }

    private func configureHotKeys() {
        let modifiers = UInt32(optionKey | cmdKey)

        let toggleRegistered = hotKeyManager.register(
            actionID: HotKeyAction.toggleOverlay.rawValue,
            keyCode: UInt32(kVK_ANSI_B),
            modifiers: modifiers
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.toggleOverlay()
            }
        }

        let lockRegistered = hotKeyManager.register(
            actionID: HotKeyAction.lockWindow.rawValue,
            keyCode: UInt32(kVK_ANSI_L),
            modifiers: modifiers
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.lockCurrentWindow()
            }
        }

        let emergencyRegistered = hotKeyManager.register(
            actionID: HotKeyAction.emergencyOff.rawValue,
            keyCode: UInt32(kVK_Escape),
            modifiers: modifiers
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.forceDisableOverlay()
            }
        }

        if toggleRegistered && lockRegistered && emergencyRegistered {
            hotKeyStatusMenuItem.title = "Hotkeys: ⌥⌘B Toggle, ⌥⌘L Lock, ⌥⌘⎋ Emergency Off"
        } else {
            hotKeyStatusMenuItem.title = "Hotkeys: Registration failed (use menu)"
        }
    }

    private func ensureRefreshLoopRunning() {
        guard refreshTimer == nil else { return }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.refreshOverlayIfNeeded()
        }

        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    private func stopRefreshLoop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refreshOverlayIfNeeded() {
        guard isOverlayEnabled else {
            return
        }

        overlayManager.setEnabled(true)

        switch overlayMode {
        case .currentDisplay:
            overlayManager.focusDisplay(accessibilityService.activeScreenByMouse())

        case .focusedWindow:
            guard accessibilityService.hasPermission() else {
                overlayMode = .currentDisplay
                updateUIState()
                overlayManager.focusDisplay(accessibilityService.activeScreenByMouse())
                return
            }

            if let target = accessibilityService.focusedWindowTarget() {
                overlayManager.focusWindow(
                    target.frame,
                    backdropStyle: focusedBackdropStyle,
                    blackOverlayOpacity: focusedBlackOverlayOpacity
                )
            } else {
                overlayManager.focusDisplay(accessibilityService.activeScreenByMouse())
            }

        case .lockedWindow:
            guard accessibilityService.hasPermission() else {
                overlayMode = .currentDisplay
                lockedTarget = nil
                updateUIState()
                overlayManager.focusDisplay(accessibilityService.activeScreenByMouse())
                return
            }

            if lockedTarget == nil {
                lockedTarget = accessibilityService.focusedWindowTarget()
            }

            guard var currentLockedTarget = lockedTarget else {
                overlayMode = .focusedWindow
                updateUIState()
                return
            }

            if let refreshedFrame = accessibilityService.frame(of: currentLockedTarget.element) {
                currentLockedTarget.frame = refreshedFrame
                lockedTarget = currentLockedTarget
                overlayManager.focusWindow(
                    refreshedFrame,
                    backdropStyle: .blackOverlay,
                    blackOverlayOpacity: 1.0
                )
            } else {
                overlayMode = .focusedWindow
                lockedTarget = nil
                overlayManager.focusDisplay(accessibilityService.activeScreenByMouse())
                updateUIState()
            }
        }
    }

    private func toggleOverlay() {
        isOverlayEnabled.toggle()

        if isOverlayEnabled {
            ensureRefreshLoopRunning()
            if overlayMode == .focusedWindow && focusedBackdropStyle == .frozenFrame {
                overlayManager.invalidateFrozenSnapshots()
            }
        } else {
            stopRefreshLoop()
            overlayManager.setEnabled(false)
        }

        refreshOverlayIfNeeded()
        updateUIState()
    }

    private func forceDisableOverlay() {
        isOverlayEnabled = false
        stopRefreshLoop()
        overlayManager.setEnabled(false)
        updateUIState()
    }

    private func switchMode(_ mode: OverlayMode) {
        overlayMode = mode

        if mode == .lockedWindow, lockedTarget == nil {
            lockedTarget = accessibilityService.focusedWindowTarget()
        }

        if mode != .currentDisplay {
            let granted = accessibilityService.hasPermission(prompt: true)
            if !granted {
                overlayMode = .currentDisplay
            }
        }

        if overlayMode == .focusedWindow, focusedBackdropStyle == .frozenFrame {
            overlayManager.invalidateFrozenSnapshots()
        }

        refreshOverlayIfNeeded()
        updateUIState()
    }

    private func setFocusedBackdropStyle(_ style: FocusedWindowBackdropStyle) {
        focusedBackdropStyle = style
        if style == .frozenFrame {
            overlayManager.invalidateFrozenSnapshots()
        }

        refreshOverlayIfNeeded()
        updateUIState()
    }

    private func updateUIState() {
        toggleMenuItem.title = isOverlayEnabled ? "Disable Focus Mask (⌥⌘B)" : "Enable Focus Mask (⌥⌘B)"

        modeDisplayMenuItem.state = overlayMode == .currentDisplay ? .on : .off
        modeFocusedMenuItem.state = overlayMode == .focusedWindow ? .on : .off
        modeLockedMenuItem.state = overlayMode == .lockedWindow ? .on : .off

        backdropFrozenMenuItem.state = focusedBackdropStyle == .frozenFrame ? .on : .off
        backdropBlackMenuItem.state = focusedBackdropStyle == .blackOverlay ? .on : .off
        backdropBlurMenuItem.state = focusedBackdropStyle == .blurOverlay ? .on : .off

        blackOpacityMenuItems.forEach { item in
            item.state = item.tag == Int((focusedBlackOverlayOpacity * 100).rounded()) ? .on : .off
        }

        let focusedModeActive = overlayMode == .focusedWindow
        backdropFrozenMenuItem.isEnabled = focusedModeActive
        backdropBlackMenuItem.isEnabled = focusedModeActive
        backdropBlurMenuItem.isEnabled = focusedModeActive

        let blackOpacityAdjustable = focusedModeActive && focusedBackdropStyle == .blackOverlay
        blackOpacityMenuItems.forEach { $0.isEnabled = blackOpacityAdjustable }

        let hasLock = lockedTarget != nil
        clearLockMenuItem.isEnabled = hasLock

        if hasLock {
            let appTitle = lockedTarget?.appName ?? "Window"
            lockWindowMenuItem.title = "Relock to Focused Window (Current: \(appTitle))"
        } else {
            lockWindowMenuItem.title = "Lock Current Window (⌥⌘L)"
        }

        let hasPermission = accessibilityService.hasPermission()
        permissionStatusMenuItem.title = hasPermission ? "Accessibility: Granted" : "Accessibility: Needed for window modes"

        statusItem.button?.title = isOverlayEnabled ? "● Focus" : "○ Focus"
    }

    @objc
    private func toggleOverlayFromMenu() {
        toggleOverlay()
    }

    @objc
    private func selectCurrentDisplayMode() {
        switchMode(.currentDisplay)
    }

    @objc
    private func selectFocusedWindowMode() {
        switchMode(.focusedWindow)
    }

    @objc
    private func selectLockedWindowMode() {
        switchMode(.lockedWindow)
    }

    @objc
    private func selectFrozenBackdrop() {
        setFocusedBackdropStyle(.frozenFrame)
    }

    @objc
    private func selectBlackBackdrop() {
        setFocusedBackdropStyle(.blackOverlay)
    }

    @objc
    private func selectBlurBackdrop() {
        setFocusedBackdropStyle(.blurOverlay)
    }

    @objc
    private func selectBlackOverlayOpacity(_ sender: NSMenuItem) {
        focusedBlackOverlayOpacity = min(max(CGFloat(sender.tag) / 100.0, 0.05), 1.0)
        refreshOverlayIfNeeded()
        updateUIState()
    }

    @objc
    private func lockCurrentWindow() {
        guard accessibilityService.hasPermission(prompt: true) else {
            updateUIState()
            return
        }

        guard let focused = accessibilityService.focusedWindowTarget() else {
            return
        }

        lockedTarget = focused
        overlayMode = .lockedWindow
        refreshOverlayIfNeeded()
        updateUIState()
    }

    @objc
    private func clearLockedWindow() {
        lockedTarget = nil
        if overlayMode == .lockedWindow {
            overlayMode = .focusedWindow
        }
        refreshOverlayIfNeeded()
        updateUIState()
    }

    @objc
    private func requestAccessibilityPermission() {
        _ = accessibilityService.hasPermission(prompt: true)
        updateUIState()
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
