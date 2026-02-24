//
// File: AppSettings.swift
// Project: ScreenCapture
//
// Description: Centralized settings model backed by UserDefaults. Stores AWS credentials,
// S3 configuration, sound preferences, and hotkey settings. The AWS secret key is stored
// in the macOS Keychain for security rather than in plain text UserDefaults.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import Foundation
import Security
import ServiceManagement

/// Manages all user-configurable settings for the app.
class AppSettings {
    /// Shared singleton instance.
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    /// AWS access key ID stored in UserDefaults.
    var awsAccessKey: String {
        get { defaults.string(forKey: Constants.Defaults.awsAccessKey) ?? "" }
        set { defaults.set(newValue, forKey: Constants.Defaults.awsAccessKey) }
    }

    /// AWS secret access key stored securely in Keychain.
    var awsSecretKey: String {
        get { readFromKeychain(account: Constants.Defaults.awsSecretKey) ?? "" }
        set { saveToKeychain(account: Constants.Defaults.awsSecretKey, value: newValue) }
    }

    /// S3 bucket name for uploading screenshots.
    var s3Bucket: String {
        get { defaults.string(forKey: Constants.Defaults.s3Bucket) ?? "" }
        set { defaults.set(newValue, forKey: Constants.Defaults.s3Bucket) }
    }

    /// AWS region for the S3 bucket (e.g., "us-east-1").
    var awsRegion: String {
        get { defaults.string(forKey: Constants.Defaults.awsRegion) ?? Constants.DefaultValues.awsRegion }
        set { defaults.set(newValue, forKey: Constants.Defaults.awsRegion) }
    }

    /// Whether to play a sound after successful upload.
    var soundEnabled: Bool {
        get {
            if defaults.object(forKey: Constants.Defaults.soundEnabled) == nil {
                return Constants.DefaultValues.soundEnabled
            }
            return defaults.bool(forKey: Constants.Defaults.soundEnabled)
        }
        set { defaults.set(newValue, forKey: Constants.Defaults.soundEnabled) }
    }

    /// Path prefix for uploaded screenshots in the S3 bucket (e.g., "screenshots/").
    var s3PathPrefix: String {
        get { defaults.string(forKey: Constants.Defaults.s3PathPrefix) ?? Constants.DefaultValues.s3PathPrefix }
        set { defaults.set(newValue, forKey: Constants.Defaults.s3PathPrefix) }
    }

    /// Pre-signed URL expiration time in seconds (default: 3600 = 1 hour).
    var signedUrlExpiration: Int {
        get {
            let val = defaults.integer(forKey: Constants.Defaults.signedUrlExpiration)
            return val > 0 ? val : Constants.DefaultValues.signedUrlExpiration
        }
        set { defaults.set(newValue, forKey: Constants.Defaults.signedUrlExpiration) }
    }

    /// Whether the app should launch at login. Reads from SMAppService and registers/unregisters accordingly.
    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[AppSettings] Failed to \(newValue ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }

    /// Returns true if all required AWS settings are configured.
    var isConfigured: Bool {
        return !awsAccessKey.isEmpty && !awsSecretKey.isEmpty && !s3Bucket.isEmpty && !awsRegion.isEmpty
    }

    // MARK: - Keychain Helpers

    /// Saves a string value to the macOS Keychain under the given account name.
    private func saveToKeychain(account: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.bundleIdentifier,
            kSecAttrAccount as String: account,
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        // Add the new item
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    /// Reads a string value from the macOS Keychain for the given account name.
    private func readFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Constants.bundleIdentifier,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }
}
