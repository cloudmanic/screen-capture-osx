//
// File: SoundService.swift
// Project: ScreenCapture
//
// Description: Plays system sounds to provide audio feedback after screenshot upload
// completes. Sound playback can be toggled on/off in app settings.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit

/// Handles playing audio feedback sounds for capture and upload events.
class SoundService {
    /// Plays the completion sound if sound is enabled in settings.
    /// Uses the built-in "Glass" system sound.
    func playCompletionSound() {
        guard AppSettings.shared.soundEnabled else { return }
        NSSound(named: NSSound.Name("Glass"))?.play()
    }

    /// Plays a short sound indicating capture started. Uses "Pop" system sound.
    func playCaptureSound() {
        guard AppSettings.shared.soundEnabled else { return }
        NSSound(named: NSSound.Name("Pop"))?.play()
    }
}
