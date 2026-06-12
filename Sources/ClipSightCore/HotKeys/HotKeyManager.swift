import Carbon
import Foundation
import OSLog

public enum HotKeyManagerError: LocalizedError, Equatable {
    case eventHandlerInstallFailed(OSStatus)
    case registrationFailed(OSStatus)

    public var errorDescription: String? {
        AppStrings(language: .chinese).hotKeyErrorMessage(self)
    }
}

public final class HotKeyManager {
    private let logger = Logger(subsystem: ClipSightLogging.subsystem, category: ClipSightLogging.Category.hotKey)
    private let signature: OSType = 0x43534F48
    private let hotKeyIdentifier: UInt32 = 1
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handler: (() -> Void)?

    public init() {}

    deinit {
        unregister()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    public func setHandler(_ handler: @escaping () -> Void) {
        self.handler = handler
    }

    public func register(_ hotKey: HotKey?) throws {
        unregister()

        guard let hotKey, hotKey.isUsable else {
            logger.info("Hot key registration skipped because no usable shortcut is configured")
            return
        }

        try installEventHandlerIfNeeded()

        let eventHotKeyID = EventHotKeyID(signature: signature, id: hotKeyIdentifier)
        var newHotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.carbonModifiers,
            eventHotKeyID,
            GetEventDispatcherTarget(),
            0,
            &newHotKeyRef
        )

        guard status == noErr else {
            logger.error("Hot key registration failed status=\(status, privacy: .public)")
            throw HotKeyManagerError.registrationFailed(status)
        }

        hotKeyRef = newHotKeyRef
        logger.info("Hot key registered keyCode=\(hotKey.keyCode, privacy: .public)")
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
            logger.info("Hot key unregistered")
        }
    }

    fileprivate func handleEvent(_ event: EventRef?) -> OSStatus {
        guard let event else {
            return noErr
        }

        var eventHotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &eventHotKeyID
        )

        guard status == noErr,
              eventHotKeyID.signature == signature,
              eventHotKeyID.id == hotKeyIdentifier else {
            return status
        }

        DispatchQueue.main.async { [weak self] in
            self?.handler?()
        }

        return noErr
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandlerRef == nil else {
            return
        }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            clipSightHotKeyEventHandler,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard status == noErr else {
            logger.error("Hot key event handler installation failed status=\(status, privacy: .public)")
            throw HotKeyManagerError.eventHandlerInstallFailed(status)
        }

        logger.info("Hot key event handler installed")
    }
}

private func clipSightHotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else {
        return noErr
    }

    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    return manager.handleEvent(event)
}
