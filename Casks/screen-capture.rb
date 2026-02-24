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
  sha256 "4a87f28c6c2a6fc390100ccfeec7b04e636197f93b895d8ece629afad91575af"

  url "https://github.com/cloudmanic/screen-capture-osx/releases/download/v#{version}/ScreenCapture-#{version}.zip"
  name "ScreenCapture"
  desc "Menu bar screenshot tool with S3 upload"
  homepage "https://github.com/cloudmanic/screen-capture-osx"

  app "ScreenCapture.app"
end
