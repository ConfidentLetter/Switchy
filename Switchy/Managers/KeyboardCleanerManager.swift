import Foundation
import AppKit

class KeyboardCleanerManager: ObservableObject {
    @Published var isActive: Bool = false
    @Published var hasAccessibilityPermission: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var heldKeys: Set<CGKeyCode> = []

    // Key codes for the unlock combo
    private let spaceKeyCode: CGKeyCode = 49
    private let tabKeyCode: CGKeyCode = 48
    private let rKeyCode: CGKeyCode = 15

    init() {
        checkAccessibilityPermission()
    }

    // MARK: - Accessibility Permission

    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        // Re-check after a delay to update UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.checkAccessibilityPermission()
        }
    }

    // MARK: - Keyboard Blocking

    func activate() {
        guard !isActive else { return }
        checkAccessibilityPermission()
        guard hasAccessibilityPermission else { return }

        heldKeys.removeAll()

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
        heldKeys.removeAll()

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

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        switch type {
        case .keyDown:
            heldKeys.insert(keyCode)
        case .keyUp:
            heldKeys.remove(keyCode)
        case .flagsChanged:
            // Track modifier keys too if needed
            break
        default:
            break
        }

        // Check for unlock combo: Space + Tab + R
        if heldKeys.contains(spaceKeyCode) &&
           heldKeys.contains(tabKeyCode) &&
           heldKeys.contains(rKeyCode) {
            deactivate()
            return Unmanaged.passUnretained(event)
        }

        // Block the event by returning nil
        return nil
    }
}
