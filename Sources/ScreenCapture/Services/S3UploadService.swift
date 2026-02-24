//
// File: S3UploadService.swift
// Project: ScreenCapture
//
// Description: Uploads screenshot PNG data to AWS S3 using a signed PUT request.
// Tracks upload progress via URLSessionTaskDelegate and reports it via callback.
// The uploaded file is set to public-read so the resulting URL can be shared.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import Foundation

/// Handles uploading screenshot images to AWS S3 with progress tracking.
class S3UploadService: NSObject {
    private var progressHandler: ((Double) -> Void)?
    private var session: URLSession?

    /// Uploads the given image data to S3 and returns the public URL on success.
    /// Progress is reported as a value from 0.0 to 1.0 via the progress callback.
    func upload(
        imageData: Data,
        filename: String,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let settings = AppSettings.shared

        guard settings.isConfigured else {
            completion(.failure(S3UploadError.notConfigured))
            return
        }

        let bucket = settings.s3Bucket
        let region = settings.awsRegion
        let prefix = settings.s3PathPrefix
        let key = "\(prefix)\(filename)"

        guard
            let url = URL(
                string:
                    "https://\(bucket).s3.\(region).amazonaws.com/\(key.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? key)"
            )
        else {
            completion(.failure(S3UploadError.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/png", forHTTPHeaderField: "Content-Type")
        request.setValue("public-read", forHTTPHeaderField: "x-amz-acl")
        request.setValue("\(imageData.count)", forHTTPHeaderField: "Content-Length")

        // Sign the request with AWS Signature V4
        let signer = AWSV4Signer(
            accessKey: settings.awsAccessKey,
            secretKey: settings.awsSecretKey,
            region: region
        )

        let payloadHash = AWSV4Signer.sha256Hex(data: imageData)
        signer.sign(request: &request, payloadHash: payloadHash)

        // Store progress handler for delegate callbacks
        self.progressHandler = progress

        // Create session with delegate for progress tracking
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        let task = session!.uploadTask(with: request, from: imageData) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(S3UploadError.invalidResponse))
                }
                return
            }

            if httpResponse.statusCode == 200 {
                let publicURL = "https://\(bucket).s3.\(region).amazonaws.com/\(key)"
                DispatchQueue.main.async {
                    completion(.success(publicURL))
                }
            } else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "No response body"
                print("S3 upload failed with status \(httpResponse.statusCode): \(body)")
                DispatchQueue.main.async {
                    completion(
                        .failure(
                            S3UploadError.httpError(statusCode: httpResponse.statusCode, body: body))
                    )
                }
            }
        }

        task.resume()
    }
}

// MARK: - URLSessionTaskDelegate for upload progress tracking

extension S3UploadService: URLSessionTaskDelegate {
    /// Called periodically during the upload to report bytes sent.
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            self.progressHandler?(progress)
        }
    }
}

/// Errors that can occur during S3 upload.
enum S3UploadError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AWS credentials not configured. Please open Settings to configure S3 upload."
        case .invalidURL:
            return "Failed to construct S3 upload URL."
        case .invalidResponse:
            return "Received an invalid response from S3."
        case .httpError(let statusCode, let body):
            return "S3 upload failed (HTTP \(statusCode)): \(body)"
        }
    }
}
