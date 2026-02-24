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

        // Collect all headers, lowercase the names, and sort alphabetically for signing.
        // AWS requires all x-amz-* headers and host to be signed.
        var headerMap: [(name: String, value: String)] = []
        if let allHeaders = request.allHTTPHeaderFields {
            for (name, value) in allHeaders {
                let lower = name.lowercased()
                // Sign host and all x-amz-* headers, plus content-type
                if lower == "host" || lower.hasPrefix("x-amz-") || lower == "content-type" {
                    headerMap.append((name: lower, value: value.trimmingCharacters(in: .whitespaces)))
                }
            }
        }
        headerMap.sort { $0.name < $1.name }

        let signedHeaderNames = headerMap.map { $0.name }
        let signedHeadersString = signedHeaderNames.joined(separator: ";")

        var canonicalHeaders = ""
        for header in headerMap {
            canonicalHeaders += "\(header.name):\(header.value)\n"
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

    /// Generates a pre-signed GET URL for an S3 object using query string authentication.
    /// The URL allows anyone with it to download the object until it expires.
    func generatePresignedURL(bucket: String, key: String, expiresIn: Int) -> String {
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amzDate = dateFormatter.string(from: now)

        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStamp = dateFormatter.string(from: now)

        let host = "\(bucket).s3.\(region).amazonaws.com"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let credential = "\(accessKey)/\(credentialScope)"

        // URI-encode the object key (each path segment separately)
        let encodedKey = key.split(separator: "/", omittingEmptySubsequences: false)
            .map { segment in
                segment.addingPercentEncoding(withAllowedCharacters: .s3Allowed) ?? String(segment)
            }
            .joined(separator: "/")
        let canonicalURI = "/\(encodedKey)"

        // Build canonical query string (parameters must be sorted by name)
        let queryParams: [(String, String)] = [
            ("X-Amz-Algorithm", "AWS4-HMAC-SHA256"),
            ("X-Amz-Credential", credential),
            ("X-Amz-Date", amzDate),
            ("X-Amz-Expires", "\(expiresIn)"),
            ("X-Amz-SignedHeaders", "host"),
        ]

        let canonicalQueryString = queryParams
            .map { "\($0.0)=\(uriEncode($0.1))" }
            .joined(separator: "&")

        // Canonical headers and signed headers (only host for pre-signed URLs)
        let canonicalHeaders = "host:\(host)\n"
        let signedHeaders = "host"

        // For pre-signed URLs the payload hash is always UNSIGNED-PAYLOAD
        let payloadHash = "UNSIGNED-PAYLOAD"

        let canonicalRequest = [
            "GET",
            canonicalURI,
            canonicalQueryString,
            canonicalHeaders,
            signedHeaders,
            payloadHash,
        ].joined(separator: "\n")

        // String to sign
        let algorithm = "AWS4-HMAC-SHA256"
        let canonicalRequestHash = sha256Hex(canonicalRequest)
        let stringToSign = [
            algorithm,
            amzDate,
            credentialScope,
            canonicalRequestHash,
        ].joined(separator: "\n")

        // Derive signing key and calculate signature
        let signingKey = deriveSigningKey(dateStamp: dateStamp)
        let signature = hmacSHA256Hex(key: signingKey, data: stringToSign.data(using: .utf8)!)

        return "https://\(host)\(canonicalURI)?\(canonicalQueryString)&X-Amz-Signature=\(signature)"
    }

    /// URI-encodes a string per AWS requirements (RFC 3986, with / NOT encoded).
    private func uriEncode(_ string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .s3Allowed) ?? string
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

/// AWS-compatible character set for URI encoding (RFC 3986 unreserved characters).
extension CharacterSet {
    static let s3Allowed: CharacterSet = {
        var allowed = CharacterSet()
        allowed.insert(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return allowed
    }()
}
