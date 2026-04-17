//
//  SwitchyTests.swift
//  SwitchyTests
//

import Testing
@testable import Switchy

@MainActor
struct KeyboardCleanerManagerTests {

    @Test func initialStateIsInactive() async throws {
        let manager = KeyboardCleanerManager()
        #expect(manager.isActive == false)
    }

    @Test func startPollingSetsPollingFlag() async throws {
        let manager = KeyboardCleanerManager()
        manager.startPollingAccessibilityPermission()
        #expect(manager.isPollingPermission == true)
        manager.stopPollingAccessibilityPermission()
    }

    @Test func stopPollingClearsPollingFlag() async throws {
        let manager = KeyboardCleanerManager()
        manager.startPollingAccessibilityPermission()
        manager.stopPollingAccessibilityPermission()
        #expect(manager.isPollingPermission == false)
    }

    @Test func startPollingIsIdempotent() async throws {
        let manager = KeyboardCleanerManager()
        manager.startPollingAccessibilityPermission()
        manager.startPollingAccessibilityPermission()
        #expect(manager.isPollingPermission == true)
        manager.stopPollingAccessibilityPermission()
        #expect(manager.isPollingPermission == false)
    }

    @Test func deactivateIsSafeWhenNotActive() async throws {
        let manager = KeyboardCleanerManager()
        manager.deactivate()
        #expect(manager.isActive == false)
    }
}
