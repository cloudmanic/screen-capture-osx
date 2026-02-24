//
// File: OverlayWindowController.swift
// Project: ScreenCapture
//
// Description: Creates and manages full-screen transparent overlay windows for each
// display. Each window covers one screen with a semi-transparent dark tint and hosts
// a SelectionOverlayView for click-drag region selection. The capture uses
// optionOnScreenBelowWindow to exclude the overlay from the screenshot.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit

/// Manages full-screen overlay windows for screenshot region selection across all displays.
class OverlayWindowController {
    /// One overlay window per connected display.
    private var overlayWindows: [NSWindow] = []

    /// Called when the user completes a region selection. Passes the CGRect in screen
    /// coordinates and the overlay's CGWindowID so the capture can exclude the overlay.
    var onSelectionComplete: ((CGRect, CGWindowID) -> Void)?

    /// Called when the user cancels the selection (Escape key).
    var onSelectionCancelled: (() -> Void)?

    /// Shows transparent overlay windows on all connected screens with the selection view.
    func showOverlay() {
        closeOverlay()

        print("[Overlay] Showing overlay on \(NSScreen.screens.count) screen(s)")

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
            window.isReleasedWhenClosed = false
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
            print("[Overlay] Window \(window.windowNumber) created on screen \(screen.frame)")
        }

        // Bring our app to front so overlay windows receive events
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes and removes all overlay windows from the screen.
    func closeOverlay() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    /// Handles a completed selection by hiding the overlay windows (alpha = 0),
    /// waiting for the compositor to update, then triggering capture and cleanup.
    private func handleSelectionComplete(_ rect: CGRect) {
        let windowID = CGWindowID(overlayWindows.first?.windowNumber ?? 0)
        print("[Overlay] Selection complete. Window ID: \(windowID), rect: \(rect)")

        // Make all overlay windows fully transparent immediately. This is
        // processed by the window server much faster than orderOut/close.
        for window in overlayWindows {
            window.alphaValue = 0
        }

        // Wait for the compositor to process the alpha change, then capture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.onSelectionComplete?(rect, windowID)
            self?.closeOverlay()
        }
    }

    /// Handles a cancelled selection by closing overlays and invoking the callback.
    private func handleSelectionCancelled() {
        closeOverlay()
        onSelectionCancelled?()
    }
}
