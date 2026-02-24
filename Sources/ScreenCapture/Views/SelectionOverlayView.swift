//
// File: SelectionOverlayView.swift
// Project: ScreenCapture
//
// Description: Custom NSView that draws a dark semi-transparent overlay across the entire
// screen and lets the user click-drag to select a rectangular region. The selected area
// is shown as a clear cutout with a white border and pixel dimension labels. Pressing
// Escape cancels the selection.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit

/// View that handles mouse-driven rectangular region selection for screenshot capture.
class SelectionOverlayView: NSView {
    /// Called when the user completes a selection, passing the selected rect in screen coordinates.
    var onSelectionComplete: ((CGRect) -> Void)?

    /// Called when the user cancels the selection (Escape key).
    var onSelectionCancelled: (() -> Void)?

    /// The starting point of the current drag operation.
    private var startPoint: NSPoint?

    /// The current selection rectangle in view coordinates.
    private var selectionRect: NSRect?

    /// Whether a drag is currently in progress.
    private var isDragging = false

    // MARK: - View Setup

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: - Drawing

    /// Draws the dark overlay with a clear cutout for the selection rectangle,
    /// plus a border and dimension label on the selection.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw semi-transparent dark overlay over the entire view
        NSColor(white: 0, alpha: 0.3).setFill()
        dirtyRect.fill()

        // If there's an active selection, cut out the selected area and draw the border
        if let rect = selectionRect, rect.width > 0, rect.height > 0 {
            // Clear the selection area to show the screen underneath
            NSColor.clear.setFill()
            rect.fill(using: .copy)

            // Draw selection border
            let borderPath = NSBezierPath(rect: rect)
            borderPath.lineWidth = 1.5
            NSColor.white.setStroke()
            borderPath.stroke()

            // Draw dimension label
            drawDimensionLabel(for: rect)

            // Draw crosshair lines extending to edges (optional, subtle)
            drawCrosshairGuides(for: rect)
        }
    }

    /// Draws a small label showing "WxH" pixel dimensions near the selection rectangle.
    private func drawDimensionLabel(for rect: NSRect) {
        let scale = window?.backingScaleFactor ?? 1.0
        let pixelWidth = Int(rect.width * scale)
        let pixelHeight = Int(rect.height * scale)
        let text = "\(pixelWidth) x \(pixelHeight)"

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]

        let textSize = (text as NSString).size(withAttributes: attributes)
        let padding: CGFloat = 6
        let labelWidth = textSize.width + padding * 2
        let labelHeight = textSize.height + padding

        // Position label below the selection rect, centered
        var labelX = rect.midX - labelWidth / 2
        var labelY = rect.minY - labelHeight - 6

        // Keep label on screen
        if labelY < 4 { labelY = rect.maxY + 6 }
        if labelX < 4 { labelX = 4 }
        if labelX + labelWidth > bounds.maxX - 4 { labelX = bounds.maxX - labelWidth - 4 }

        let labelRect = NSRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)

        // Draw label background
        let bgPath = NSBezierPath(roundedRect: labelRect, xRadius: 4, yRadius: 4)
        NSColor(white: 0, alpha: 0.75).setFill()
        bgPath.fill()

        // Draw text
        let textPoint = NSPoint(x: labelRect.minX + padding, y: labelRect.minY + padding / 2)
        (text as NSString).draw(at: textPoint, withAttributes: attributes)
    }

    /// Draws subtle guide lines from the selection edges to the screen edges.
    private func drawCrosshairGuides(for rect: NSRect) {
        NSColor(white: 1.0, alpha: 0.15).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 0.5

        // Top edge guide
        path.move(to: NSPoint(x: rect.midX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.midX, y: bounds.maxY))

        // Bottom edge guide
        path.move(to: NSPoint(x: rect.midX, y: rect.minY))
        path.line(to: NSPoint(x: rect.midX, y: bounds.minY))

        // Left edge guide
        path.move(to: NSPoint(x: rect.minX, y: rect.midY))
        path.line(to: NSPoint(x: bounds.minX, y: rect.midY))

        // Right edge guide
        path.move(to: NSPoint(x: rect.maxX, y: rect.midY))
        path.line(to: NSPoint(x: bounds.maxX, y: rect.midY))

        path.stroke()
    }

    // MARK: - Mouse Events

    /// Records the starting point of the selection drag.
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        selectionRect = nil
        isDragging = true
    }

    /// Updates the selection rectangle as the user drags.
    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let width = abs(current.x - start.x)
        let height = abs(current.y - start.y)

        selectionRect = NSRect(x: x, y: y, width: width, height: height)
        needsDisplay = true
    }

    /// Finalizes the selection and converts the rect to screen coordinates for capture.
    override func mouseUp(with event: NSEvent) {
        isDragging = false

        guard let rect = selectionRect, rect.width > 2, rect.height > 2 else {
            // Selection too small, treat as cancelled
            selectionRect = nil
            needsDisplay = true
            return
        }

        // Convert from view coordinates to screen coordinates (CoreGraphics uses top-left origin)
        guard let window = self.window, let screen = window.screen else { return }

        // NSView coordinates -> NSScreen coordinates
        let windowRect = convert(rect, to: nil)
        let screenRect = window.convertToScreen(windowRect)

        // NSScreen has origin at bottom-left of primary display.
        // CoreGraphics (CGWindowListCreateImage) uses origin at top-left.
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let cgRect = CGRect(
            x: screenRect.origin.x,
            y: primaryScreenHeight - screenRect.origin.y - screenRect.height,
            width: screenRect.width,
            height: screenRect.height
        )

        onSelectionComplete?(cgRect)
    }

    // MARK: - Keyboard Events

    /// Handles Escape key to cancel the selection.
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            // Escape key
            onSelectionCancelled?()
        }
    }
}
