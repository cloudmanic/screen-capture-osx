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
        statusBarController.onImageDropped = { [weak self] url in
            self?.handleImageDrop(url)
        }

        // Wire up the overlay selection callbacks
        overlayController.onSelectionComplete = { [weak self] rect, windowID in
            self?.handleSelectionComplete(rect, excludingWindow: windowID)
        }
        overlayController.onSelectionCancelled = {
            print("Selection cancelled")
        }

        // Register global hotkey (Cmd+Shift+6)
        hotkeyService.onHotkeyTriggered = { [weak self] in
            self?.startCapture()
        }
        hotkeyService.register()

        // Check screen recording permission on launch and prompt if not granted.
        // This triggers the system dialog once upfront rather than failing silently on first capture.
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

        overlayController.showOverlay()
    }

    /// Handles a completed region selection: captures the screen, then uploads to S3.
    /// The overlay controller has already hidden the overlay windows before calling this.
    private func handleSelectionComplete(_ rect: CGRect, excludingWindow: CGWindowID) {
        performCapture(rect: rect)
    }

    /// Captures the screen region and initiates the S3 upload with progress tracking.
    private func performCapture(rect: CGRect) {
        let captureResult = captureService.captureRegion(rect)
        let imageData: Data

        switch captureResult {
        case .success(let data):
            imageData = data
        case .failure(let error):
            if case .permissionDenied = error {
                permissionManager.showPermissionAlert()
            } else {
                showError(error.localizedDescription)
            }
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

    /// Handles an image file dropped onto the status bar icon: reads the file and uploads to S3.
    private func handleImageDrop(_ fileURL: URL) {
        if !AppSettings.shared.isConfigured {
            showNotConfiguredAlert()
            return
        }

        guard let imageData = try? Data(contentsOf: fileURL) else {
            showError("Failed to read image file: \(fileURL.lastPathComponent)")
            return
        }

        soundService.playCaptureSound()

        let ext = fileURL.pathExtension.lowercased()
        let filename = captureService.generateFilename(ext: ext.isEmpty ? "png" : ext)
        showProgressHUD()

        print("[ScreenCapture] Uploading dropped file: \(fileURL.lastPathComponent) (\(imageData.count) bytes)")

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

    /// Handles a failed upload: shows detailed error in HUD and logs the full error.
    private func handleUploadFailure(error: Error) {
        let message: String
        if let s3Error = error as? S3UploadError {
            message = s3Error.errorDescription ?? error.localizedDescription
        } else {
            message = error.localizedDescription
        }
        ClipboardManager.copyToClipboard(message)
        progressHUD?.showError(message)
        print("[ScreenCapture] Upload failed (copied to clipboard): \(message)")
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
