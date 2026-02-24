//
// File: Constants.swift
// Project: ScreenCapture
//
// Description: App-wide constants including bundle identifiers, default hotkey settings,
// UserDefaults keys, and S3 upload configuration defaults.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import Carbon

/// App-wide constants used throughout the application.
struct Constants {
    /// Bundle identifier for the app.
    static let bundleIdentifier = "com.cloudmanic.screencapture"

    /// Default hotkey: Cmd+Shift+6 (avoids conflicting with macOS built-in Cmd+Shift+4/5).
    static let defaultHotkeyKeyCode: UInt32 = UInt32(kVK_ANSI_6)
    static let defaultHotkeyModifiers: UInt32 = UInt32(cmdKey | shiftKey)

    /// Four-character code used to identify our hotkey with Carbon event system.
    static let hotkeySignature: OSType = OSType(
        (UInt32(Character("S").asciiValue!) << 24)
            | (UInt32(Character("C").asciiValue!) << 16)
            | (UInt32(Character("a").asciiValue!) << 8)
            | UInt32(Character("p").asciiValue!)
    )

    /// Hotkey ID used with Carbon RegisterEventHotKey.
    static let hotkeyID: UInt32 = 1

    /// UserDefaults keys for persisting settings.
    struct Defaults {
        static let awsAccessKey = "awsAccessKey"
        static let awsSecretKey = "awsSecretKeyRef"
        static let s3Bucket = "s3Bucket"
        static let awsRegion = "awsRegion"
        static let soundEnabled = "soundEnabled"
        static let s3PathPrefix = "s3PathPrefix"
        static let signedUrlExpiration = "signedUrlExpiration"
    }

    /// Default values for settings.
    struct DefaultValues {
        static let awsRegion = "us-east-1"
        static let soundEnabled = true
        static let s3PathPrefix = "screenshots/"
        static let signedUrlExpiration = 3600
    }
}
