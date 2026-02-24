# CLAUDE.md - ScreenCapture

## Build & Test Commands

```bash
make run        # Build debug, code sign, and launch the app
make build      # Build release version
make debug      # Build debug version with code signing
make sign       # Build release and code sign with entitlements
make install    # Build, sign, and install to /Applications
make test       # Run tests (requires Xcode: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer)
make clean      # Remove build artifacts
```

## Architecture

This is a macOS menu bar app built with Swift Package Manager (Swift 5.9+, macOS 13.0+). No external dependencies — all AWS signing is implemented in pure Swift using CryptoKit.

**Two SPM targets:**
- `ScreenCaptureLib` — all app code (library target)
- `ScreenCapture` — executable entry point (`Sources/ScreenCaptureApp/main.swift`)

**Linked system frameworks:** AppKit, Carbon, CoreGraphics, Security, ServiceManagement, CryptoKit

### Key Components

- **AppDelegate** (`AppDelegate.swift`) — Central coordinator that wires all services together and manages the capture workflow
- **Controllers** — StatusBarController (menu bar), OverlayWindowController (selection UI), SettingsWindowController (settings window)
- **Services** — HotkeyService (Carbon global hotkey), ScreenCaptureService (CoreGraphics capture), S3UploadService (upload + signed URLs), AWSV4Signer (AWS Sig V4), SoundService (audio feedback)
- **Models** — AppSettings (singleton, UserDefaults + Keychain for secrets)
- **Views** — SelectionOverlayView (NSView for region selection), SettingsView (SwiftUI form), ProgressIndicatorView (floating HUD)
- **Utilities** — Constants, ClipboardManager, PermissionManager

### Capture Workflow

Hotkey/menu click → OverlayWindowController shows overlays on all screens → User drags to select region → Overlay dismissed → ScreenCaptureService captures via CGWindowListCreateImage → S3UploadService uploads with progress → Pre-signed URL copied to clipboard

## Code Style

- Detailed comments above every function (public and private)
- File headers with description, creation date, and copyright
- No external dependencies — pure Swift + system frameworks
- Result<T, E> for error handling in capture operations
- Callback closures for inter-component communication (not Combine/async-await)

## Important Details

- The app is **not sandboxed** (required for CGWindowListCreateImage)
- AWS secret key is stored in **macOS Keychain**, not UserDefaults
- Global hotkey uses **Carbon Events** (not accessibility permissions)
- Debug builds **must be code signed** with entitlements for screen recording permission to persist
- The app uses `LSUIElement: true` (menu bar only, no dock icon)
- Screen coordinates require conversion between NSScreen (bottom-left origin) and CoreGraphics (top-left origin)
- Bundle ID: `com.cloudmanic.screencapture`
