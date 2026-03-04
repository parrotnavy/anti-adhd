import AppKit
import CoreGraphics

private final class OverlayWindow: NSWindow {
    private var lastCutout: CGRect?
    private var lastCornerRadius: CGFloat = 0
    private let blurView = NSVisualEffectView()

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        hasShadow = false
        isOpaque = false
        ignoresMouseEvents = true
        level = .statusBar
        backgroundColor = .clear
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = NSColor.black.cgColor

        if let contentView {
            blurView.frame = contentView.bounds
            blurView.autoresizingMask = [.width, .height]
            blurView.blendingMode = .behindWindow
            blurView.material = .hudWindow
            blurView.state = .active
            blurView.isHidden = true
            contentView.addSubview(blurView)
        }

        orderOut(nil)
    }

    func refreshFrame(for screen: NSScreen) {
        setFrame(screen.frame, display: false)
    }

    func applyBackdrop(style: FocusedWindowBackdropStyle, blackOpacity: CGFloat, frozenImage: CGImage?) {
        guard let contentView else { return }

        switch style {
        case .frozenFrame:
            blurView.isHidden = true
            if let frozenImage {
                contentView.layer?.contents = frozenImage
                contentView.layer?.contentsGravity = .resize
                contentView.layer?.backgroundColor = NSColor.clear.cgColor
            } else {
                contentView.layer?.contents = nil
                contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(blackOpacity).cgColor
            }

        case .blackOverlay:
            blurView.isHidden = true
            contentView.layer?.contents = nil
            contentView.layer?.backgroundColor = NSColor.black.withAlphaComponent(blackOpacity).cgColor

        case .blurOverlay:
            contentView.layer?.contents = nil
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
            blurView.isHidden = false
        }
    }

    func setCutout(globalRect: CGRect?, cornerRadius: CGFloat = 12) {
        if lastCutout == globalRect, lastCornerRadius == cornerRadius {
            return
        }

        guard let contentView else { return }

        contentView.wantsLayer = true

        guard let globalRect else {
            contentView.layer?.mask = nil
            lastCutout = nil
            lastCornerRadius = 0
            return
        }

        let windowRect = convertFromScreen(globalRect)
        let localRect = contentView.convert(windowRect, from: nil)
        let bounds = contentView.bounds
        let clampedCornerRadius = max(0, min(cornerRadius, min(localRect.width, localRect.height) / 2))

        let path = CGMutablePath()
        path.addRect(bounds)
        path.addRoundedRect(in: localRect, cornerWidth: clampedCornerRadius, cornerHeight: clampedCornerRadius)

        let maskLayer = CAShapeLayer()
        maskLayer.frame = bounds
        maskLayer.path = path
        maskLayer.fillRule = .evenOdd
        maskLayer.allowsEdgeAntialiasing = true

        contentView.layer?.mask = maskLayer
        contentView.layer?.allowsEdgeAntialiasing = true
        lastCutout = globalRect
        lastCornerRadius = cornerRadius
    }
}

@MainActor
final class OverlayManager {
    private let focusedCutoutCornerRadius: CGFloat = 12
    private var windowsByScreenID: [Int: OverlayWindow] = [:]
    private var frozenSnapshotsByScreenID: [Int: CGImage] = [:]
    private(set) var isEnabled = false

    init() {
        rebuildWindowsIfNeeded()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc
    private func handleScreenParametersChanged(_ notification: Notification) {
        invalidateFrozenSnapshots()
        rebuildWindowsIfNeeded()
    }

    func setEnabled(_ enabled: Bool) {
        guard isEnabled != enabled else { return }

        isEnabled = enabled

        if enabled {
            rebuildWindowsIfNeeded()
            windowsByScreenID.values.forEach { $0.orderFrontRegardless() }
        } else {
            hideAll()
            invalidateFrozenSnapshots()
        }
    }

    func hideAll() {
        windowsByScreenID.values.forEach { window in
            window.setCutout(globalRect: nil)
            window.orderOut(nil)
        }
    }

    func invalidateFrozenSnapshots() {
        frozenSnapshotsByScreenID.removeAll()
    }

    func focusDisplay(_ targetScreen: NSScreen?) {
        guard isEnabled else {
            hideAll()
            return
        }

        rebuildWindowsIfNeeded()
        let targetID = targetScreen.flatMap(screenID(for:))

        for screen in NSScreen.screens {
            guard let id = screenID(for: screen), let window = windowsByScreenID[id] else { continue }

            if id == targetID {
                window.orderOut(nil)
            } else {
                window.applyBackdrop(style: .blackOverlay, blackOpacity: 1.0, frozenImage: nil)
                window.setCutout(globalRect: nil)
                window.orderFrontRegardless()
            }
        }
    }

    func focusWindow(
        _ globalWindowRect: CGRect?,
        backdropStyle: FocusedWindowBackdropStyle,
        blackOverlayOpacity: CGFloat
    ) {
        guard isEnabled else {
            hideAll()
            return
        }

        rebuildWindowsIfNeeded()

        guard let globalWindowRect else {
            hideAll()
            return
        }

        let clampedOpacity = min(max(blackOverlayOpacity, 0.05), 1.0)

        if backdropStyle == .frozenFrame {
            captureFrozenSnapshotsIfNeeded()
        }

        for screen in NSScreen.screens {
            guard let id = screenID(for: screen), let window = windowsByScreenID[id] else { continue }

            let frozenImage = backdropStyle == .frozenFrame ? frozenSnapshotsByScreenID[id] : nil
            window.applyBackdrop(style: backdropStyle, blackOpacity: clampedOpacity, frozenImage: frozenImage)

            let intersection = screen.frame.intersection(globalWindowRect)
            if intersection.isNull || intersection.isEmpty {
                window.setCutout(globalRect: nil)
            } else {
                window.setCutout(globalRect: intersection, cornerRadius: focusedCutoutCornerRadius)
            }
            window.orderFrontRegardless()
        }
    }

    private func captureFrozenSnapshotsIfNeeded() {
        let expectedIDs = Set(NSScreen.screens.compactMap(screenID(for:)))
        let existingIDs = Set(frozenSnapshotsByScreenID.keys)
        guard expectedIDs != existingIDs else {
            return
        }

        windowsByScreenID.values.forEach { $0.orderOut(nil) }
        frozenSnapshotsByScreenID.removeAll()

        for screen in NSScreen.screens {
            guard let id = screenID(for: screen) else { continue }

            let displayID = CGDirectDisplayID(truncatingIfNeeded: id)
            if let image = CGDisplayCreateImage(displayID) {
                frozenSnapshotsByScreenID[id] = image
            }
        }
    }

    private func rebuildWindowsIfNeeded() {
        let previousIDs = Set(windowsByScreenID.keys)
        let currentScreenIDs = Set(NSScreen.screens.compactMap(screenID(for:)))
        let staleIDs = previousIDs.subtracting(currentScreenIDs)

        for staleID in staleIDs {
            windowsByScreenID[staleID]?.close()
            windowsByScreenID.removeValue(forKey: staleID)
        }

        for screen in NSScreen.screens {
            guard let id = screenID(for: screen) else { continue }

            if let existing = windowsByScreenID[id] {
                existing.refreshFrame(for: screen)
            } else {
                windowsByScreenID[id] = OverlayWindow(screen: screen)
            }
        }

        if previousIDs != currentScreenIDs {
            invalidateFrozenSnapshots()
        }

        if !isEnabled {
            hideAll()
        }
    }

    private func screenID(for screen: NSScreen) -> Int? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return number.intValue
    }
}
