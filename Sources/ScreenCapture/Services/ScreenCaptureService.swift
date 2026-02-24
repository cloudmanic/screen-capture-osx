//
// File: ScreenCaptureService.swift
// Project: ScreenCapture
//
// Description: Captures a specific region of the screen using CGWindowListCreateImage.
// The captured image is returned as PNG data ready for upload. Handles coordinate
// conversion for the CoreGraphics coordinate system.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit
import CoreGraphics

/// Captures screenshots of specific screen regions using CoreGraphics.
class ScreenCaptureService {
    /// Captures the specified screen region and returns the image as PNG data.
    /// The rect should be in the global display coordinate system (origin at top-left
    /// of the primary display, as used by CoreGraphics).
    func captureRegion(_ rect: CGRect) -> Data? {
        guard let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            print("Failed to capture screen region")
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }

    /// Generates a unique filename for a screenshot using the current timestamp and a short UUID.
    func generateFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let shortUUID = UUID().uuidString.prefix(8).lowercased()
        return "\(timestamp)_\(shortUUID).png"
    }
}
