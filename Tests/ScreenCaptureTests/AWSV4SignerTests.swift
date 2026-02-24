//
// File: AWSV4SignerTests.swift
// Project: ScreenCapture
//
// Description: Tests for the AWS Signature V4 signing implementation to verify
// correct request signing, signing key derivation, and SHA-256 hashing.
//
// Created: 2026-02-24
// Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
//

import Foundation
import XCTest

@testable import ScreenCaptureLib

final class AWSV4SignerTests: XCTestCase {
    /// Verifies that SHA-256 hex digest produces the correct output for empty input.
    func testSHA256HexDigestEmpty() {
        let emptyHash = AWSV4Signer.sha256Hex(data: Data())
        XCTAssertEqual(emptyHash, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    /// Verifies that a signed request contains the required Authorization header.
    func testSignedRequestContainsAuthorizationHeader() {
        let signer = AWSV4Signer(
            accessKey: "AKIAIOSFODNN7EXAMPLE",
            secretKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            region: "us-east-1"
        )

        var request = URLRequest(url: URL(string: "https://examplebucket.s3.us-east-1.amazonaws.com/test.png")!)
        request.httpMethod = "PUT"
        request.setValue("image/png", forHTTPHeaderField: "Content-Type")

        let payloadHash = AWSV4Signer.sha256Hex(data: Data())
        signer.sign(request: &request, payloadHash: payloadHash)

        let authHeader = request.value(forHTTPHeaderField: "Authorization")
        XCTAssertNotNil(authHeader)
        XCTAssertTrue(authHeader!.hasPrefix("AWS4-HMAC-SHA256"))
        XCTAssertTrue(authHeader!.contains("Credential=AKIAIOSFODNN7EXAMPLE"))
        XCTAssertTrue(authHeader!.contains("SignedHeaders=host;x-amz-content-sha256;x-amz-date"))
        XCTAssertTrue(authHeader!.contains("Signature="))
    }

    /// Verifies that x-amz-date and x-amz-content-sha256 headers are set after signing.
    func testSignedRequestContainsRequiredHeaders() {
        let signer = AWSV4Signer(
            accessKey: "TESTKEY",
            secretKey: "TESTSECRET",
            region: "us-west-2"
        )

        var request = URLRequest(url: URL(string: "https://mybucket.s3.us-west-2.amazonaws.com/file.png")!)
        request.httpMethod = "PUT"

        let payloadHash = AWSV4Signer.sha256Hex(data: Data())
        signer.sign(request: &request, payloadHash: payloadHash)

        XCTAssertNotNil(request.value(forHTTPHeaderField: "x-amz-date"))
        XCTAssertNotNil(request.value(forHTTPHeaderField: "x-amz-content-sha256"))
        XCTAssertNotNil(request.value(forHTTPHeaderField: "Host"))
    }
}
