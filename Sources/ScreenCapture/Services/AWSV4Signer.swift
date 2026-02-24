//
// File: AWSV4Signer.swift
// Project: ScreenCapture
//
// Description: Pure Swift implementation of AWS Signature Version 4 request signing.
// This avoids pulling in the massive AWS SDK by implementing the signing algorithm
// directly using CryptoKit (HMAC-SHA256) and Foundation. Follows the AWS SigV4 spec:
// https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import CryptoKit
import Foundation

/// Signs HTTP requests with AWS Signature Version 4 for authenticating S3 API calls.
struct AWSV4Signer {
    let accessKey: String
    let secretKey: String
    let region: String
    let service: String = "s3"

    /// Signs the given URLRequest by adding the required AWS authentication headers.
    /// The payloadHash should be the hex-encoded SHA-256 hash of the request body.
    func sign(request: inout URLRequest, payloadHash: String) {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        // ISO 8601 basic format: 20260224T120000Z
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = dateFormatter.string(from: now)

        // Date stamp: 20260224
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dateFormatter.string(from: now)

        guard let url = request.url, let host = url.host else { return }

        // Step 1: Add required headers
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")

        // Step 2: Build canonical request
        let method = request.httpMethod ?? "GET"
        let canonicalURI = url.path.isEmpty ? "/" : url.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? url.path
        let canonicalQueryString = url.query ?? ""

        // Collect and sort headers for signing
        let signedHeaderNames = ["host", "x-amz-content-sha256", "x-amz-date"]
        let signedHeadersString = signedHeaderNames.joined(separator: ";")

        var canonicalHeaders = ""
        for name in signedHeaderNames {
            let value = request.value(forHTTPHeaderField: name) ?? ""
            canonicalHeaders += "\(name):\(value.trimmingCharacters(in: .whitespaces))\n"
        }

        let canonicalRequest = [
            method,
            canonicalURI,
            canonicalQueryString,
            canonicalHeaders,
            signedHeadersString,
            payloadHash,
        ].joined(separator: "\n")

        // Step 3: Build string to sign
        let algorithm = "AWS4-HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let canonicalRequestHash = sha256Hex(canonicalRequest)

        let stringToSign = [
            algorithm,
            amzDate,
            credentialScope,
            canonicalRequestHash,
        ].joined(separator: "\n")

        // Step 4: Derive signing key
        let signingKey = deriveSigningKey(dateStamp: dateStamp)

        // Step 5: Calculate signature
        let signature = hmacSHA256Hex(key: signingKey, data: stringToSign.data(using: .utf8)!)

        // Step 6: Set Authorization header
        let authorization =
            "\(algorithm) Credential=\(accessKey)/\(credentialScope), SignedHeaders=\(signedHeadersString), Signature=\(signature)"
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
    }

    /// Derives the AWS SigV4 signing key by chaining HMAC-SHA256 operations:
    /// kDate -> kRegion -> kService -> kSigning
    private func deriveSigningKey(dateStamp: String) -> SymmetricKey {
        let kSecret = "AWS4\(secretKey)".data(using: .utf8)!
        let kDate = hmacSHA256(key: SymmetricKey(data: kSecret), data: dateStamp.data(using: .utf8)!)
        let kRegion = hmacSHA256(key: kDate, data: region.data(using: .utf8)!)
        let kService = hmacSHA256(key: kRegion, data: service.data(using: .utf8)!)
        let kSigning = hmacSHA256(key: kService, data: "aws4_request".data(using: .utf8)!)
        return kSigning
    }

    /// Computes HMAC-SHA256 and returns the result as a SymmetricKey for chaining.
    private func hmacSHA256(key: SymmetricKey, data: Data) -> SymmetricKey {
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return SymmetricKey(data: Data(mac))
    }

    /// Computes HMAC-SHA256 and returns the hex-encoded string.
    private func hmacSHA256Hex(key: SymmetricKey, data: Data) -> String {
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return mac.map { String(format: "%02x", $0) }.joined()
    }

    /// Computes SHA-256 hash of a string and returns the hex-encoded digest.
    private func sha256Hex(_ string: String) -> String {
        let data = string.data(using: .utf8)!
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Computes SHA-256 hash of data and returns the hex-encoded digest.
    static func sha256Hex(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
