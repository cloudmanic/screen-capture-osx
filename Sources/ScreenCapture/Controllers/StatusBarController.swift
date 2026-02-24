//
// File: StatusBarController.swift
// Project: ScreenCapture
//
// Description: Creates and manages the menu bar status item (system tray icon) with a
// dropdown menu providing access to capture, settings, and quit actions.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit

/// Manages the menu bar status item and its dropdown menu.
class StatusBarController {
    /// The system status bar item.
    private var statusItem: NSStatusItem?

    /// The drop target overlay for accepting dragged image files.
    private var dropTargetView: DropTargetView?

    /// Called when the user clicks "Capture Region" in the menu.
    var onCaptureRequested: (() -> Void)?

    /// Called when the user clicks "Settings..." in the menu.
    var onSettingsRequested: (() -> Void)?

    /// Called when the user drops an image file onto the status bar icon.
    var onImageDropped: ((URL) -> Void)?

    /// Creates the status bar item with an icon and builds the dropdown menu.
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Use SF Symbol for the menu bar icon (camera viewfinder)
            if let image = NSImage(
                systemSymbolName: "camera.viewfinder",
                accessibilityDescription: "ScreenCapture"
            ) {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "SC"
            }
        }

        // Add a transparent drop target overlay to accept image file drags.
        if let button = statusItem?.button {
            let dropView = DropTargetView(frame: button.bounds)
            dropView.autoresizingMask = [.width, .height]
            dropView.onImageDropped = { [weak self] url in
                self?.onImageDropped?(url)
            }
            button.addSubview(dropView)
            dropTargetView = dropView
        }

        buildMenu()
    }

    /// Builds the dropdown menu with Capture, Settings, and Quit items.
    private func buildMenu() {
        let menu = NSMenu()

        let captureItem = NSMenuItem(
            title: "Capture Region",
            action: #selector(captureClicked),
            keyEquivalent: ""
        )
        captureItem.target = self

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(settingsClicked),
            keyEquivalent: ","
        )
        settingsItem.target = self

        let quitItem = NSMenuItem(
            title: "Quit ScreenCapture",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self

        menu.addItem(captureItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    /// Handles the Capture Region menu item click.
    @objc private func captureClicked() {
        onCaptureRequested?()
    }

    /// Handles the Settings menu item click.
    @objc private func settingsClicked() {
        onSettingsRequested?()
    }

    /// Handles the Quit menu item click.
    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }
}
