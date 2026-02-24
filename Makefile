APP_NAME = ScreenCapture
BUILD_DIR_RELEASE = .build/release
BUILD_DIR_DEBUG = .build/debug
APP_BUNDLE = $(APP_NAME).app

.PHONY: build debug run install clean sign help

## Build release version and assemble .app bundle
build:
	swift build -c release
	@echo "Assembling $(APP_BUNDLE)..."
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR_RELEASE)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	@cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	@echo "Build complete: $(APP_BUNDLE)"

## Build debug version, assemble .app bundle, and code sign with entitlements
debug:
	swift build -c debug
	@echo "Assembling $(APP_BUNDLE) (debug)..."
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(APP_BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR_DEBUG)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	@cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	codesign --force --deep --sign - \
		--entitlements Resources/ScreenCapture.entitlements \
		$(APP_BUNDLE)
	@echo "Debug build complete: $(APP_BUNDLE)"

## Build debug and run the app
run: debug
	@echo "Launching $(APP_BUNDLE)..."
	@open $(APP_BUNDLE)

## Code sign the app bundle with entitlements
sign: build
	codesign --force --deep --sign - \
		--entitlements Resources/ScreenCapture.entitlements \
		$(APP_BUNDLE)
	@echo "Signed: $(APP_BUNDLE)"

## Install to /Applications
install: sign
	@cp -r $(APP_BUNDLE) /Applications/
	@echo "Installed to /Applications/$(APP_BUNDLE)"

## Remove build artifacts
clean:
	swift package clean
	rm -rf $(APP_BUNDLE)
	@echo "Clean complete"

## Run tests (requires Xcode for XCTest framework)
test:
	DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

## Show available targets
help:
	@echo "Available targets:"
	@echo "  make build    - Build release version"
	@echo "  make debug    - Build debug version"
	@echo "  make run      - Build debug and launch app"
	@echo "  make sign     - Build release and code sign"
	@echo "  make install  - Build, sign, and install to /Applications"
	@echo "  make clean    - Remove all build artifacts"
	@echo "  make test     - Run tests"
	@echo "  make help     - Show this help"
