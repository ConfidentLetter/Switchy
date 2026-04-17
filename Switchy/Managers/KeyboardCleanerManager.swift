import Foundation
import AppKit

class KeyboardCleanerManager: ObservableObject {
    @Published var isActive: Bool = false
    @Published var hasAccessibilityPermission: Bool = false
    @Published private(set) var isPollingPermission: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionPollTimer: Timer?

    init() {
        checkAccessibilityPermission()
    }

    // MARK: - Accessibility Permission

    func checkAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        if hasAccessibilityPermission != trusted {
            hasAccessibilityPermission = trusted
        }
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        startPollingAccessibilityPermission()
    }

    func startPollingAccessibilityPermission() {
        stopPollingAccessibilityPermission()
        isPollingPermission = true
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.checkAccessibilityPermission()
            if self.hasAccessibilityPermission {
                self.stopPollingAccessibilityPermission()
            }
        }
    }

    func stopPollingAccessibilityPermission() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
        isPollingPermission = false
    }

    // MARK: - Keyboard Blocking

    func activate() {
        guard !isActive else { return }
        checkAccessibilityPermission()
        guard hasAccessibilityPermission else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

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
        // If the tap gets disabled by the system, re-enable it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Block all keyboard input; unlock happens via the on-screen button.
        return nil
    }
}
