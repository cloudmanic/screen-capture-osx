//
// File: SettingsView.swift
// Project: ScreenCapture
//
// Description: SwiftUI view for the Settings window. Provides form fields for AWS
// credentials (access key, secret key, bucket, region), S3 path prefix, and sound
// toggle. Includes a "Test Connection" button to verify S3 access.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import SwiftUI

/// SwiftUI view presenting the app's settings form.
struct SettingsView: View {
    @State private var awsAccessKey: String = AppSettings.shared.awsAccessKey
    @State private var awsSecretKey: String = AppSettings.shared.awsSecretKey
    @State private var s3Bucket: String = AppSettings.shared.s3Bucket
    @State private var awsRegion: String = AppSettings.shared.awsRegion
    @State private var s3PathPrefix: String = AppSettings.shared.s3PathPrefix
    @State private var soundEnabled: Bool = AppSettings.shared.soundEnabled
    @State private var testResult: String = ""
    @State private var isTesting: Bool = false

    /// Available AWS regions for the dropdown picker.
    private let awsRegions = [
        "us-east-1", "us-east-2", "us-west-1", "us-west-2",
        "eu-west-1", "eu-west-2", "eu-west-3", "eu-central-1",
        "ap-southeast-1", "ap-southeast-2", "ap-northeast-1", "ap-northeast-2",
        "ap-south-1", "sa-east-1", "ca-central-1",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("ScreenCapture Settings")
                .font(.headline)
                .padding(.bottom, 16)

            Form {
                // AWS Credentials Section
                Section("AWS Credentials") {
                    TextField("Access Key ID", text: $awsAccessKey)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Secret Access Key", text: $awsSecretKey)
                        .textFieldStyle(.roundedBorder)
                }

                // S3 Configuration Section
                Section("S3 Configuration") {
                    TextField("Bucket Name", text: $s3Bucket)
                        .textFieldStyle(.roundedBorder)

                    Picker("Region", selection: $awsRegion) {
                        ForEach(awsRegions, id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }

                    TextField("Path Prefix", text: $s3PathPrefix)
                        .textFieldStyle(.roundedBorder)

                    Text("Screenshots will be uploaded to: s3://\(s3Bucket)/\(s3PathPrefix)<filename>.png")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Sound Section
                Section("Sound") {
                    Toggle("Play sound on upload complete", isOn: $soundEnabled)
                }

                // Hotkey Info Section
                Section("Hotkey") {
                    HStack {
                        Text("Capture Screenshot:")
                        Spacer()
                        Text("Cmd + Shift + 6")
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            .formStyle(.grouped)

            // Action Buttons
            HStack {
                // Test connection button
                Button(action: testConnection) {
                    if isTesting {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    Text(isTesting ? "Testing..." : "Test Connection")
                }
                .disabled(isTesting || awsAccessKey.isEmpty || awsSecretKey.isEmpty || s3Bucket.isEmpty)

                if !testResult.isEmpty {
                    Text(testResult)
                        .font(.caption)
                        .foregroundColor(testResult.contains("Success") ? .green : .red)
                }

                Spacer()

                Button("Save") {
                    saveSettings()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 12)
        }
        .padding(20)
        .frame(width: 500, height: 520)
    }

    /// Saves all settings to AppSettings (UserDefaults + Keychain for secret key).
    private func saveSettings() {
        AppSettings.shared.awsAccessKey = awsAccessKey
        AppSettings.shared.awsSecretKey = awsSecretKey
        AppSettings.shared.s3Bucket = s3Bucket
        AppSettings.shared.awsRegion = awsRegion
        AppSettings.shared.s3PathPrefix = s3PathPrefix
        AppSettings.shared.soundEnabled = soundEnabled

        // Close the settings window
        NSApp.keyWindow?.close()
    }

    /// Tests the S3 connection by attempting a HEAD request on the bucket.
    private func testConnection() {
        // Save current values first
        AppSettings.shared.awsAccessKey = awsAccessKey
        AppSettings.shared.awsSecretKey = awsSecretKey
        AppSettings.shared.s3Bucket = s3Bucket
        AppSettings.shared.awsRegion = awsRegion

        isTesting = true
        testResult = ""

        let url = URL(string: "https://\(s3Bucket).s3.\(awsRegion).amazonaws.com/")!
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let signer = AWSV4Signer(accessKey: awsAccessKey, secretKey: awsSecretKey, region: awsRegion)
        let payloadHash = AWSV4Signer.sha256Hex(data: Data())
        signer.sign(request: &request, payloadHash: payloadHash)

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                isTesting = false
                if let error = error {
                    testResult = "Error: \(error.localizedDescription)"
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 404 || httpResponse.statusCode == 301 {
                        testResult = "Success! Connection verified."
                    } else if httpResponse.statusCode == 403 {
                        testResult = "Error: Access denied. Check credentials."
                    } else {
                        testResult = "Error: HTTP \(httpResponse.statusCode)"
                    }
                }
            }
        }.resume()
    }
}
