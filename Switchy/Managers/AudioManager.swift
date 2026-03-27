import Foundation
import CoreAudio
import Combine

struct AudioDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let isInput: Bool
    let isOutput: Bool
}

class AudioManager: ObservableObject {
    @Published var outputDevices: [AudioDevice] = []
    @Published var inputDevices: [AudioDevice] = []
    @Published var currentOutputDeviceID: AudioDeviceID = 0
    @Published var currentInputDeviceID: AudioDeviceID = 0

    init() {
        refreshDevices()
        refreshCurrentDevices()
        startListening()
    }

    // MARK: - Device Enumeration

    func refreshDevices() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize
        )
        guard status == noErr else { return }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else { return }

        var outputs: [AudioDevice] = []
        var inputs: [AudioDevice] = []

        for deviceID in deviceIDs {
            guard let name = getDeviceName(deviceID) else { continue }
            let hasOutput = deviceHasStreams(deviceID, scope: kAudioObjectPropertyScopeOutput)
            let hasInput = deviceHasStreams(deviceID, scope: kAudioObjectPropertyScopeInput)

            let device = AudioDevice(id: deviceID, name: name, isInput: hasInput, isOutput: hasOutput)

            if hasOutput { outputs.append(device) }
            if hasInput { inputs.append(device) }
        }

        DispatchQueue.main.async {
            self.outputDevices = outputs
            self.inputDevices = inputs
        }
    }

    func refreshCurrentDevices() {
        currentOutputDeviceID = getDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
        currentInputDeviceID = getDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
    }

    // MARK: - Device Switching

    func setDefaultOutput(_ deviceID: AudioDeviceID) {
        setDefaultDevice(deviceID, selector: kAudioHardwarePropertyDefaultOutputDevice)
        DispatchQueue.main.async {
            self.currentOutputDeviceID = deviceID
        }
    }

    func setDefaultInput(_ deviceID: AudioDeviceID) {
        setDefaultDevice(deviceID, selector: kAudioHardwarePropertyDefaultInputDevice)
        DispatchQueue.main.async {
            self.currentInputDeviceID = deviceID
        }
    }

    // MARK: - Private Helpers

    private func getDeviceName(_ deviceID: AudioDeviceID) -> String? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var name = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &name) { namePtr in
            AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, namePtr)
        }
        guard status == noErr else { return nil }
        return name as String
    }

    private func deviceHasStreams(_ deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        return status == noErr && dataSize > 0
    }

    private func getDefaultDevice(selector: AudioObjectPropertySelector) -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize,
            &deviceID
        )
        return deviceID
    }

    private func setDefaultDevice(_ deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var mutableDeviceID = deviceID
        AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableDeviceID
        )
    }

    // MARK: - Device Change Listening

    private func startListening() {
        addListener(selector: kAudioHardwarePropertyDevices) { [weak self] in
            self?.refreshDevices()
            self?.refreshCurrentDevices()
        }
        addListener(selector: kAudioHardwarePropertyDefaultOutputDevice) { [weak self] in
            self?.refreshCurrentDevices()
        }
        addListener(selector: kAudioHardwarePropertyDefaultInputDevice) { [weak self] in
            self?.refreshCurrentDevices()
        }
    }

    private func addListener(selector: AudioObjectPropertySelector, callback: @escaping () -> Void) {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Retain the wrapper to prevent deallocation
        _ = Unmanaged.passRetained(CallbackWrapper(callback))

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main
        ) { _, _ in
            callback()
        }
    }
}

// Helper to prevent callback from being deallocated
private class CallbackWrapper {
    let callback: () -> Void
    init(_ callback: @escaping () -> Void) {
        self.callback = callback
    }
}
