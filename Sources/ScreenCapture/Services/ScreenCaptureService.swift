//
// File: ScreenCaptureService.swift
// Project: ScreenCapture
//
// Description: Captures a specific region of the screen using CGWindowListCreateImage.
// The captured image is returned as PNG data ready for upload. Handles coordinate
// conversion for the CoreGraphics coordinate system. Detects blank captures that
// indicate missing screen recording permission.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit
import CoreGraphics

/// Errors that can occur during screen capture.
enum ScreenCaptureError: LocalizedError {
    case captureFailed
    case permissionDenied
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .captureFailed:
            return "Failed to capture screen region."
        case .permissionDenied:
            return "Screen recording permission not granted. Please enable it in System Settings > Privacy & Security > Screen Recording."
        case .encodingFailed:
            return "Failed to encode captured image as PNG."
        }
    }
}

/// Captures screenshots of specific screen regions using CoreGraphics.
class ScreenCaptureService {
    /// Captures the specified screen region and returns the image as PNG data.
    /// The rect should be in the global display coordinate system (origin at top-left
    /// of the primary display, as used by CoreGraphics).
    /// If excludingWindow is provided, captures only windows below that window ID,
    /// which allows capturing the screen while the overlay is still visible.
    /// Returns a Result so callers get a clear error for permission issues vs other failures.
    func captureRegion(_ rect: CGRect, excludingWindow: CGWindowID = kCGNullWindowID) -> Result<Data, ScreenCaptureError> {
        let listOption: CGWindowListOption = excludingWindow != kCGNullWindowID
            ? .optionOnScreenBelowWindow
            : .optionOnScreenOnly

        guard let cgImage = CGWindowListCreateImage(
            rect,
            listOption,
            excludingWindow,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            print("[ScreenCapture] CGWindowListCreateImage returned nil for rect: \(rect)")
            return .failure(.captureFailed)
        }

        // Detect blank/black image which indicates missing screen recording permission.
        // Without permission, macOS returns a 1x1 or all-black image.
        if cgImage.width <= 1 || cgImage.height <= 1 {
            print("[ScreenCapture] Captured image is \(cgImage.width)x\(cgImage.height) - likely permission denied")
            return .failure(.permissionDenied)
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("[ScreenCapture] Failed to encode CGImage as PNG")
            return .failure(.encodingFailed)
        }

        print("[ScreenCapture] Captured \(cgImage.width)x\(cgImage.height) image (\(pngData.count) bytes)")
        return .success(pngData)
    }

    /// Generates a unique filename using the current timestamp and a short UUID.
    /// The extension defaults to "png" but can be overridden for dropped image files.
    func generateFilename(ext: String = "png") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let shortUUID = UUID().uuidString.prefix(8).lowercased()
        return "\(timestamp)_\(shortUUID).\(ext)"
    }
}
