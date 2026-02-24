//
// File: AppDelegate.swift
// Project: ScreenCapture
//
// Description: Central app coordinator that initializes all services on launch and
// orchestrates the screenshot capture workflow: hotkey/menu trigger -> overlay selection ->
// screen capture -> S3 upload with progress -> clipboard copy -> sound notification.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import AppKit

/// Application delegate that wires together all services and manages the capture workflow.
public class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Services and Controllers

    private let statusBarController = StatusBarController()
    private let overlayController = OverlayWindowController()
    private let settingsController = SettingsWindowController()
    private let hotkeyService = HotkeyService()
    private let captureService = ScreenCaptureService()
    private let uploadService = S3UploadService()
    private let soundService = SoundService()
    private let permissionManager = PermissionManager()

    /// The floating HUD that shows upload progress.
    private var progressHUD: ProgressHUDWindow?

    /// Public initializer required for access from the executable target.
    public override init() {
        super.init()
    }

    // MARK: - App Lifecycle

    /// Called when the app finishes launching. Sets up all services and checks permissions.
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up the menu bar icon and menu
        statusBarController.setup()
        statusBarController.onCaptureRequested = { [weak self] in
            self?.startCapture()
        }
        statusBarController.onSettingsRequested = { [weak self] in
            self?.settingsController.show()
        }

        // Wire up the overlay selection callbacks
        overlayController.onSelectionComplete = { [weak self] rect in
            self?.handleSelectionComplete(rect)
        }
        overlayController.onSelectionCancelled = {
            print("Selection cancelled")
        }

        // Register global hotkey (Cmd+Shift+6)
        hotkeyService.onHotkeyTriggered = { [weak self] in
            self?.startCapture()
        }
        hotkeyService.register()

        // Check screen recording permission on first launch
        if !permissionManager.hasScreenRecordingPermission() {
            permissionManager.requestScreenRecordingPermission()
        }

        print("ScreenCapture launched. Press Cmd+Shift+6 to capture.")
    }

    /// Called when the app is about to terminate. Cleans up the hotkey registration.
    public func applicationWillTerminate(_ notification: Notification) {
        hotkeyService.unregister()
    }

    // MARK: - Capture Workflow

    /// Initiates the screenshot capture flow by showing the selection overlay.
    private func startCapture() {
        // Check settings first
        if !AppSettings.shared.isConfigured {
            showNotConfiguredAlert()
            return
        }

        // Check permission
        if !permissionManager.hasScreenRecordingPermission() {
            permissionManager.showPermissionAlert()
            return
        }

        overlayController.showOverlay()
    }

    /// Handles a completed region selection: captures the screen, then uploads to S3.
    private func handleSelectionComplete(_ rect: CGRect) {
        // Small delay to let overlay windows fully close before capturing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.performCapture(rect: rect)
        }
    }

    /// Captures the screen region and initiates the S3 upload with progress tracking.
    private func performCapture(rect: CGRect) {
        guard let imageData = captureService.captureRegion(rect) else {
            showError("Failed to capture screenshot")
            return
        }

        // Play capture sound
        soundService.playCaptureSound()

        // Generate filename and show progress HUD
        let filename = captureService.generateFilename()
        showProgressHUD()

        // Upload to S3
        uploadService.upload(
            imageData: imageData,
            filename: filename,
            progress: { [weak self] progress in
                self?.progressHUD?.updateProgress(progress)
            },
            completion: { [weak self] result in
                switch result {
                case .success(let url):
                    self?.handleUploadSuccess(url: url)
                case .failure(let error):
                    self?.handleUploadFailure(error: error)
                }
            }
        )
    }

    /// Handles a successful upload: copies URL to clipboard, plays sound, shows success HUD.
    private func handleUploadSuccess(url: String) {
        ClipboardManager.copyToClipboard(url)
        soundService.playCompletionSound()
        progressHUD?.showSuccess()
        print("Screenshot uploaded: \(url)")
    }

    /// Handles a failed upload: shows error in HUD and logs the error.
    private func handleUploadFailure(error: Error) {
        let message = error.localizedDescription
        progressHUD?.showError("Upload failed")
        print("Upload failed: \(message)")
    }

    // MARK: - UI Helpers

    /// Shows the progress HUD window for tracking upload progress.
    private func showProgressHUD() {
        progressHUD = ProgressHUDWindow()
        progressHUD?.updateProgress(0)
        progressHUD?.orderFront(nil)
    }

    /// Shows an alert when AWS settings are not configured, with option to open Settings.
    private func showNotConfiguredAlert() {
        let alert = NSAlert()
        alert.messageText = "S3 Not Configured"
        alert.informativeText = "Please configure your AWS credentials and S3 bucket in Settings before capturing screenshots."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            settingsController.show()
        }
    }

    /// Shows a brief error notification.
    private func showError(_ message: String) {
        print("Error: \(message)")
    }
}
