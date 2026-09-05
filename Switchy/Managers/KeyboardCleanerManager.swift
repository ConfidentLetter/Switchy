import Foundation
import AppKit

class KeyboardCleanerManager: ObservableObject {
    @Published var isActive: Bool = false
    @Published var hasAccessibilityPermission: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var accessibilityPermissionTimer: Timer?
    private var appActivationObserver: NSObjectProtocol?

    init() {
        checkAccessibilityPermission()
        startAccessibilityPermissionMonitoring()
        appActivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAccessibilityPermission()
        }
    }

    deinit {
        accessibilityPermissionTimer?.invalidate()
        if let appActivationObserver {
            NotificationCenter.default.removeObserver(appActivationObserver)
        }
    }

    // MARK: - Accessibility Permission

    func checkAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        let update = { [weak self] in
            guard let self, self.hasAccessibilityPermission != isTrusted else { return }
            self.hasAccessibilityPermission = isTrusted
        }

        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.async(execute: update)
        }
    }

    private func startAccessibilityPermissionMonitoring() {
        accessibilityPermissionTimer?.invalidate()
        accessibilityPermissionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            self.checkAccessibilityPermission()
        }
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        startAccessibilityPermissionMonitoring()
    }

    // MARK: - Keyboard Blocking

    func activate() {
        guard !isActive else { return }
        checkAccessibilityPermission()
        guard hasAccessibilityPermission else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        // Store self pointer for the callback
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<KeyboardCleanerManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handleKeyEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPointer
        ) else {
            print("Failed to create event tap. Accessibility permission may not be granted.")
            return
        }

        eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        DispatchQueue.main.async {
            self.isActive = true
        }
    }

    func deactivate() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil

        DispatchQueue.main.async {
            self.isActive = false
        }
    }

    // MARK: - Event Handling

    private func handleKeyEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // If the tap gets disabled by the system, re-enable it
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Block the event by returning nil
        return nil
    }
}
