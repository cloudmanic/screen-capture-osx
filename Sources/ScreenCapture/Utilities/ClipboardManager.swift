//
// File: ClipboardManager.swift
// Project: ScreenCapture
//
// Description: Handles copying text (screenshot URLs) to the macOS system clipboard
// using NSPasteboard.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit

/// Manages clipboard operations for copying URLs after screenshot upload.
class ClipboardManager {
    /// Copies the given string to the system clipboard.
    static func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
