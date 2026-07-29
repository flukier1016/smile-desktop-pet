#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
APP_DIR="$PROJECT_DIR/笑笑桌宠.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
BUILD_DIR="$PROJECT_DIR/.build"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$BUILD_DIR"

if [[ -f "$PROJECT_DIR/Assets/pet_chroma.png" ]]; then
  python3 "$PROJECT_DIR/Tools/remove_chroma.py" \
    "$PROJECT_DIR/Assets/pet_chroma.png" \
    "$PROJECT_DIR/Assets/pet.png"
fi

if [[ ! -f "$PROJECT_DIR/Assets/pet.png" ]]; then
  echo "Missing required sprite: Assets/pet.png" >&2
  exit 1
fi
if [[ ! -f "$PROJECT_DIR/Assets/AppIcon.icns" ]]; then
  echo "Missing required icon: Assets/AppIcon.icns" >&2
  exit 1
fi

xcrun --sdk macosx swiftc \
  -swift-version 5 \
  -parse-as-library \
  -O \
  -target arm64-apple-macos13.0 \
  "$PROJECT_DIR/Sources/Awareness.swift" \
  "$PROJECT_DIR/Sources/ControlCenter.swift" \
  "$PROJECT_DIR/Sources/PetApp.swift" \
  -framework AppKit \
  -framework QuartzCore \
  -framework ScreenCaptureKit \
  -framework Vision \
  -o "$BUILD_DIR/SmilePet-arm64"

xcrun --sdk macosx swiftc \
  -swift-version 5 \
  -parse-as-library \
  -O \
  -target x86_64-apple-macos13.0 \
  "$PROJECT_DIR/Sources/Awareness.swift" \
  "$PROJECT_DIR/Sources/ControlCenter.swift" \
  "$PROJECT_DIR/Sources/PetApp.swift" \
  -framework AppKit \
  -framework QuartzCore \
  -framework ScreenCaptureKit \
  -framework Vision \
  -o "$BUILD_DIR/SmilePet-x86_64"

lipo -create \
  "$BUILD_DIR/SmilePet-arm64" \
  "$BUILD_DIR/SmilePet-x86_64" \
  -output "$MACOS_DIR/SmilePet"

cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Assets/pet.png" "$RESOURCES_DIR/pet.png"
cp "$PROJECT_DIR/Assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
chmod +x "$MACOS_DIR/SmilePet"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "Built: $APP_DIR"
