//
// File: PermissionManager.swift
// Project: ScreenCapture
//
// Description: Handles checking and requesting macOS screen recording permission.
// Screen capture APIs return blank images without this permission, so we check
// on launch and guide the user to System Settings if not granted.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit
import CoreGraphics

/// Manages screen recording permission checks and requests.
class PermissionManager {
    /// Checks if the app has screen recording permission without prompting the user.
    func hasScreenRecordingPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }

    /// Requests screen recording permission, which triggers the macOS system prompt on first call.
    /// After the first call, subsequent calls do nothing - the user must go to System Settings manually.
    func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }

    /// Shows an alert directing the user to enable screen recording in System Settings.
    func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "ScreenCapture needs screen recording access to capture screenshots.\n\nPlease go to System Settings > Privacy & Security > Screen Recording and enable ScreenCapture."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }

    /// Opens the Screen Recording section of System Settings directly.
    private func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
