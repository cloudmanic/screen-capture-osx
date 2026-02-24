//
// File: SettingsWindowController.swift
// Project: ScreenCapture
//
// Description: Manages the Settings window by embedding the SwiftUI SettingsView inside
// an NSHostingController. The window is created once and reused on subsequent opens.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit
import SwiftUI

/// Manages the app's settings window, hosting a SwiftUI view in an AppKit window.
class SettingsWindowController {
    /// The settings window instance, created lazily and reused.
    private var window: NSWindow?

    /// Shows the settings window, creating it if it doesn't exist yet. If already
    /// open, brings it to the front.
    func show() {
        if window == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)
            let newWindow = NSWindow(contentViewController: hostingController)
            newWindow.title = "ScreenCapture Settings"
            newWindow.styleMask = [.titled, .closable]
            newWindow.setContentSize(NSSize(width: 500, height: 520))
            newWindow.isReleasedWhenClosed = false
            window = newWindow
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
