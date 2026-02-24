//
// File: DropTargetView.swift
// Project: ScreenCapture
//
// Description: Transparent NSView overlay added to the status bar button that accepts
// image file drag-and-drop. Validates dropped files are supported image types and
// forwards the file URL via callback. Passes through mouse events so the button's
// menu behavior is unaffected.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit

/// Transparent overlay view that accepts image file drops on the status bar icon.
class DropTargetView: NSView {
    /// Called when a valid image file is dropped. Provides the file URL.
    var onImageDropped: ((URL) -> Void)?

    /// Supported image file extensions for drag-and-drop upload.
    private let supportedExtensions = ["png", "jpg", "jpeg", "gif", "webp", "tiff", "bmp", "heic"]

    // MARK: - Initialization

    /// Initializes the view and registers for file URL drag types.
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    // MARK: - NSDraggingDestination

    /// Validates the dragged item is a supported image file and shows the copy cursor.
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard imageURL(from: sender) != nil else {
            return []
        }
        return .copy
    }

    /// Reads the dropped image file URL and calls the onImageDropped callback.
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = imageURL(from: sender) else {
            return false
        }

        onImageDropped?(url)
        return true
    }

    // MARK: - Mouse Event Pass-Through

    /// Passes mouse down events through to the status bar button underneath.
    override func mouseDown(with event: NSEvent) {
        superview?.mouseDown(with: event)
    }

    /// Passes mouse up events through to the status bar button underneath.
    override func mouseUp(with event: NSEvent) {
        superview?.mouseUp(with: event)
    }

    // MARK: - Helpers

    /// Extracts the first valid image file URL from the dragging pasteboard.
    private func imageURL(from sender: NSDraggingInfo) -> URL? {
        guard let items = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] else {
            return nil
        }

        return items.first { url in
            supportedExtensions.contains(url.pathExtension.lowercased())
        }
    }
}
