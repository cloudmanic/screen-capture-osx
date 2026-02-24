#
# File: screen-capture.rb
# Project: ScreenCapture
#
# Description: Homebrew Cask formula for installing ScreenCapture. Points to the
# latest GitHub release zip. The sha256 is updated automatically by `make release`.
#
# Created: 2026-02-24
# Copyright 2026 Cloudmanic Labs, LLC. All rights reserved.
#

cask "screen-capture" do
  version "1.0.0"
  sha256 "ab005704041da1624bed9d0126aafac549edbe1360de503df362afbe977075c3"

  url "https://github.com/cloudmanic/screen-capture-osx/releases/download/v#{version}/ScreenCapture-#{version}.zip"
  name "ScreenCapture"
  desc "Menu bar screenshot tool with S3 upload"
  homepage "https://github.com/cloudmanic/screen-capture-osx"

  app "ScreenCapture.app"
end
