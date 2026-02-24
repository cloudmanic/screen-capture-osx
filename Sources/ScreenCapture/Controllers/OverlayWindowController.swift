//
// File: OverlayWindowController.swift
// Project: ScreenCapture
//
// Description: Creates and manages full-screen transparent overlay windows for each
// display. Each window covers one screen with a semi-transparent dark tint and hosts
// a SelectionOverlayView for click-drag region selection.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit

/// Manages full-screen overlay windows for screenshot region selection across all displays.
class OverlayWindowController {
    /// One overlay window per connected display.
    private var overlayWindows: [NSWindow] = []

    /// Called when the user completes a region selection with the CGRect in screen coordinates.
    var onSelectionComplete: ((CGRect) -> Void)?

    /// Called when the user cancels the selection (Escape key).
    var onSelectionCancelled: (() -> Void)?

    /// Shows transparent overlay windows on all connected screens with the selection view.
    func showOverlay() {
        closeOverlay()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )

            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let selectionView = SelectionOverlayView(frame: screen.frame)
            selectionView.onSelectionComplete = { [weak self] rect in
                self?.handleSelectionComplete(rect)
            }
            selectionView.onSelectionCancelled = { [weak self] in
                self?.handleSelectionCancelled()
            }

            window.contentView = selectionView
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(selectionView)

            overlayWindows.append(window)
        }

        // Bring our app to front so overlay windows receive events
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes and removes all overlay windows.
    func closeOverlay() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    /// Handles a completed selection by closing overlays and invoking the callback.
    private func handleSelectionComplete(_ rect: CGRect) {
        closeOverlay()
        onSelectionComplete?(rect)
    }

    /// Handles a cancelled selection by closing overlays and invoking the callback.
    private func handleSelectionCancelled() {
        closeOverlay()
        onSelectionCancelled?()
    }
}
