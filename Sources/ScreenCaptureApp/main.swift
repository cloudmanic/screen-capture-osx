//
// File: main.swift
// Project: ScreenCapture
//
// Description: Application entry point. Creates the NSApplication instance, configures it
// as a menu-bar-only app (no dock icon), sets the AppDelegate, and starts the run loop.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit
import ScreenCaptureLib

// Create the application instance
let app = NSApplication.shared

// Set activation policy to accessory (no dock icon, no app menu bar)
app.setActivationPolicy(.accessory)

// Create and set the app delegate
let delegate = AppDelegate()
app.delegate = delegate

// Start the run loop
app.run()
