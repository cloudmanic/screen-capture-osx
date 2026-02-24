# ScreenCapture

A lightweight macOS menu bar app that captures screen regions and uploads them to AWS S3. After uploading, a pre-signed URL is automatically copied to your clipboard for easy sharing.

## Features

- **Global hotkey** (Cmd+Shift+6) to trigger screen capture from anywhere
- **Interactive region selection** with click-drag overlay across all connected displays
- **S3 upload** with real-time progress HUD and automatic pre-signed URL generation
- **Clipboard integration** - shareable URL copied automatically on upload
- **Configurable settings** - AWS credentials, S3 bucket/region/path, URL expiration, sound feedback
- **Launch at login** support via macOS native login items
- **Pure Swift AWS Signature V4** implementation with no external dependencies
- **Keychain storage** for AWS secret key security
- **Menu bar only** - no dock icon, stays out of your way

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9+
- AWS S3 bucket with valid credentials
- Screen Recording permission (prompted on first launch)

## Building

The project uses Swift Package Manager and includes a Makefile for convenience:

```bash
# Build debug version and run
make run

# Build release version
make build

# Build, code sign, and install to /Applications
make install

# Run tests (requires Xcode)
make test

# Clean build artifacts
make clean
```

## Setup

1. Build and launch the app (`make run`)
2. Grant Screen Recording permission when prompted
3. Click the camera icon in the menu bar and open **Settings**
4. Enter your AWS credentials and S3 bucket configuration
5. Click **Test Connection** to verify, then **Save**
6. Press **Cmd+Shift+6** to capture a region

## How It Works

1. Press **Cmd+Shift+6** or click **Capture Region** from the menu bar
2. A translucent overlay appears on all displays
3. Click and drag to select a region (dimensions shown in real-time)
4. The selected region is captured and uploaded to S3
5. A progress HUD tracks the upload
6. The pre-signed URL is copied to your clipboard with a sound notification

Press **Escape** to cancel a selection.

## Settings

| Setting | Description |
|---------|-------------|
| AWS Access Key | Your AWS IAM access key ID |
| AWS Secret Key | Stored securely in macOS Keychain |
| S3 Bucket | Target bucket name for uploads |
| Region | AWS region (15 regions supported) |
| Path Prefix | S3 key prefix (default: `screenshots/`) |
| URL Expiration | Pre-signed URL lifetime (15 min to 7 days) |
| Launch at Login | Start automatically on macOS login |
| Sound | Audio feedback on capture and upload completion |

## Project Structure

```
Sources/
  ScreenCaptureApp/
    main.swift                  # App entry point
  ScreenCapture/
    AppDelegate.swift           # Central coordinator and capture workflow
    Controllers/
      StatusBarController.swift       # Menu bar icon and dropdown menu
      OverlayWindowController.swift   # Full-screen selection overlays
      SettingsWindowController.swift   # Settings window host
    Models/
      AppSettings.swift         # Settings persistence (UserDefaults + Keychain)
    Services/
      HotkeyService.swift       # Global hotkey via Carbon Events
      ScreenCaptureService.swift # CoreGraphics screen capture
      S3UploadService.swift      # S3 upload with progress and signed URLs
      AWSV4Signer.swift          # AWS Signature V4 request signing
      SoundService.swift         # Audio feedback
    Views/
      SelectionOverlayView.swift # Region selection UI
      SettingsView.swift          # SwiftUI settings form
      ProgressIndicatorView.swift # Upload progress HUD
    Utilities/
      Constants.swift            # App-wide constants
      ClipboardManager.swift     # Clipboard operations
      PermissionManager.swift    # Screen recording permission handling
Tests/
  ScreenCaptureTests/
    AWSV4SignerTests.swift       # AWS signing unit tests
```

## License

Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
