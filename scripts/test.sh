#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/.build"

mkdir -p "$BUILD_DIR"

xcrun --sdk macosx swiftc \
  -swift-version 5 \
  -parse-as-library \
  -target arm64-apple-macos13.0 \
  "$PROJECT_DIR/Sources/Awareness.swift" \
  "$PROJECT_DIR/Tests/AwarenessClassifierTests.swift" \
  -framework AppKit \
  -framework ScreenCaptureKit \
  -framework Vision \
  -o "$BUILD_DIR/AwarenessClassifierTests"

"$BUILD_DIR/AwarenessClassifierTests"
