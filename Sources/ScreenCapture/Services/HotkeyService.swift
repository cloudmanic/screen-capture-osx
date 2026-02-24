//
// File: HotkeyService.swift
// Project: ScreenCapture
//
// Description: Registers and manages global keyboard shortcuts using the Carbon Event
// system (RegisterEventHotKey). This approach works globally without requiring
// accessibility permissions, unlike CGEvent taps or NSEvent global monitors.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import Carbon
import Foundation

/// Manages global hotkey registration using Carbon Events for triggering screenshot capture.
class HotkeyService {
    /// Reference to the registered hotkey, used for unregistering on cleanup.
    private var hotkeyRef: EventHotKeyRef?

    /// Callback invoked when the registered hotkey is pressed.
    var onHotkeyTriggered: (() -> Void)?

    /// Registers the global hotkey (default: Cmd+Shift+6) with the Carbon Event system.
    /// The hotkey fires even when the app is not in the foreground.
    func register() {
        // Store self in the global so the C callback can reach us
        HotkeyService.sharedInstance = self

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = Constants.hotkeySignature
        hotKeyID.id = Constants.hotkeyID

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Install event handler on the application event target
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyCallback,
            1,
            &eventType,
            nil,
            nil
        )

        guard status == noErr else {
            print("Failed to install hotkey event handler: \(status)")
            return
        }

        // Register the actual hotkey combination
        let registerStatus = RegisterEventHotKey(
            Constants.defaultHotkeyKeyCode,
            Constants.defaultHotkeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        guard registerStatus == noErr else {
            print("Failed to register hotkey: \(registerStatus)")
            return
        }

        print("Global hotkey registered: Cmd+Shift+6")
    }

    /// Unregisters the global hotkey and cleans up the Carbon event handler.
    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        HotkeyService.sharedInstance = nil
    }

    deinit {
        unregister()
    }

    // MARK: - Static callback bridge

    /// Static reference so the C-function callback can invoke our instance method.
    fileprivate static var sharedInstance: HotkeyService?
}

/// C-compatible callback function for Carbon hotkey events. This is called by the
/// Carbon Event system when the registered hotkey is pressed. It bridges to the
/// HotkeyService instance via the static sharedInstance reference.
private func hotkeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    HotkeyService.sharedInstance?.onHotkeyTriggered?()
    return noErr
}
