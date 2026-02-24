//
// File: ProgressIndicatorView.swift
// Project: ScreenCapture
//
// Description: A small floating HUD window that displays upload progress as a circular
// indicator with percentage text. Shows near the menu bar area and auto-dismisses
// after the upload completes with a brief success or error message.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit

/// Floating HUD window that shows S3 upload progress with a circular indicator.
class ProgressHUDWindow: NSPanel {
    /// The circular progress view inside this window.
    private let progressView = CircularProgressView()

    /// The status label showing "Uploading..." or "Done!" text.
    private let statusLabel = NSTextField(labelWithString: "Uploading...")

    /// Creates and configures the HUD window with the progress indicator and label.
    init() {
        let size = NSSize(width: 140, height: 140)
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: screenFrame.maxX - size.width - 20,
            y: screenFrame.maxY - size.height - 20
        )

        super.init(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = NSColor(white: 0.1, alpha: 0.9)
        self.hasShadow = true
        self.isMovableByWindowBackground = true

        let contentView = NSView(frame: NSRect(origin: .zero, size: size))

        // Add circular progress view
        progressView.frame = NSRect(x: 30, y: 40, width: 80, height: 80)
        contentView.addSubview(progressView)

        // Add status label
        statusLabel.frame = NSRect(x: 0, y: 10, width: size.width, height: 20)
        statusLabel.alignment = .center
        statusLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        statusLabel.textColor = .white
        contentView.addSubview(statusLabel)

        self.contentView = contentView
    }

    /// Updates the progress indicator (0.0 to 1.0) and the status text.
    func updateProgress(_ progress: Double) {
        progressView.progress = progress
        let percent = Int(progress * 100)
        statusLabel.stringValue = "Uploading... \(percent)%"
        progressView.needsDisplay = true
    }

    /// Shows a success state briefly, then dismisses the HUD after a delay.
    func showSuccess() {
        statusLabel.stringValue = "Copied to clipboard!"
        progressView.progress = 1.0
        progressView.showSuccess = true
        progressView.needsDisplay = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.dismiss()
        }
    }

    /// Shows an error message briefly, then dismisses the HUD after a delay.
    func showError(_ message: String) {
        statusLabel.stringValue = message
        progressView.showError = true
        progressView.needsDisplay = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.dismiss()
        }
    }

    /// Dismisses and closes the HUD window.
    func dismiss() {
        orderOut(nil)
    }
}

/// Custom NSView that draws a circular progress ring with percentage or status icon.
class CircularProgressView: NSView {
    /// Current progress value from 0.0 to 1.0.
    var progress: Double = 0.0

    /// When true, shows a checkmark instead of the progress ring.
    var showSuccess = false

    /// When true, shows an X instead of the progress ring.
    var showError = false

    /// Draws the circular progress indicator, or a success/error icon.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 4
        let lineWidth: CGFloat = 4

        // Draw background circle (track)
        let trackPath = NSBezierPath()
        trackPath.appendArc(
            withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        trackPath.lineWidth = lineWidth
        NSColor(white: 1.0, alpha: 0.2).setStroke()
        trackPath.stroke()

        if showSuccess {
            // Draw checkmark
            NSColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1.0).setStroke()
            let check = NSBezierPath()
            check.lineWidth = 3
            check.lineCapStyle = .round
            check.move(to: NSPoint(x: center.x - 15, y: center.y))
            check.line(to: NSPoint(x: center.x - 5, y: center.y - 12))
            check.line(to: NSPoint(x: center.x + 15, y: center.y + 12))
            check.stroke()
        } else if showError {
            // Draw X
            NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0).setStroke()
            let x = NSBezierPath()
            x.lineWidth = 3
            x.lineCapStyle = .round
            x.move(to: NSPoint(x: center.x - 12, y: center.y + 12))
            x.line(to: NSPoint(x: center.x + 12, y: center.y - 12))
            x.move(to: NSPoint(x: center.x + 12, y: center.y + 12))
            x.line(to: NSPoint(x: center.x - 12, y: center.y - 12))
            x.stroke()
        } else {
            // Draw progress arc (starts from 12 o'clock, goes clockwise)
            let startAngle: CGFloat = 90
            let endAngle = startAngle - CGFloat(progress) * 360

            let progressPath = NSBezierPath()
            progressPath.appendArc(
                withCenter: center, radius: radius,
                startAngle: startAngle, endAngle: endAngle, clockwise: true)
            progressPath.lineWidth = lineWidth
            progressPath.lineCapStyle = .round
            NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0).setStroke()
            progressPath.stroke()

            // Draw percentage text in center
            let percent = "\(Int(progress * 100))%"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .semibold),
                .foregroundColor: NSColor.white,
            ]
            let textSize = (percent as NSString).size(withAttributes: attributes)
            let textPoint = NSPoint(
                x: center.x - textSize.width / 2,
                y: center.y - textSize.height / 2
            )
            (percent as NSString).draw(at: textPoint, withAttributes: attributes)
        }
    }
}
