#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/.build"

case "$(uname -m)" in
  arm64) target="arm64-apple-macos13.0" ;;
  x86_64) target="x86_64-apple-macos13.0" ;;
  *)
    echo "Unsupported CI architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

mkdir -p "$BUILD_DIR"
xcrun --sdk macosx swiftc \
  -swift-version 5 \
  -parse-as-library \
  -Onone \
  -target "$target" \
  "$PROJECT_DIR/Sources/Awareness.swift" \
  "$PROJECT_DIR/Sources/CompanionProgress.swift" \
  "$PROJECT_DIR/Sources/ControlCenter.swift" \
  "$PROJECT_DIR/Sources/PetApp.swift" \
  -framework AppKit \
  -framework QuartzCore \
  -framework ScreenCaptureKit \
  -framework Vision \
  -o "$BUILD_DIR/SmilePet-codeql"

echo "Built CodeQL analysis binary for $target"
