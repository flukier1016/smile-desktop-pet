#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BUILD_DIR="$PROJECT_DIR/.build"

mkdir -p "$BUILD_DIR"
case "$(uname -m)" in
  arm64) target="arm64-apple-macos13.0" ;;
  x86_64) target="x86_64-apple-macos13.0" ;;
  *) echo "Unsupported architecture" >&2; exit 1 ;;
esac

xcrun --sdk macosx swiftc \
  -swift-version 5 \
  -parse-as-library \
  -target "$target" \
  "$PROJECT_DIR/Sources/Awareness.swift" \
  "$PROJECT_DIR/Tests/AwarenessClassifierTests.swift" \
  -framework AppKit \
  -framework ScreenCaptureKit \
  -framework Vision \
  -o "$BUILD_DIR/AwarenessClassifierTests"

"$BUILD_DIR/AwarenessClassifierTests"

xcrun --sdk macosx swiftc \
  -swift-version 5 \
  -parse-as-library \
  -target "$target" \
  "$PROJECT_DIR/Sources/CompanionProgress.swift" \
  "$PROJECT_DIR/Tests/CompanionProgressTests.swift" \
  -o "$BUILD_DIR/CompanionProgressTests"

"$BUILD_DIR/CompanionProgressTests"

xcrun --sdk macosx swiftc \
  -swift-version 5 -parse-as-library -target "$target" \
  "$PROJECT_DIR/Sources/Awareness.swift" \
  "$PROJECT_DIR/Tests/OCRScanStateTests.swift" \
  -framework AppKit -framework ScreenCaptureKit -framework Vision \
  -o "$BUILD_DIR/OCRScanStateTests"
"$BUILD_DIR/OCRScanStateTests"

xcrun --sdk macosx swiftc \
  -swift-version 5 -parse-as-library -target "$target" \
  "$PROJECT_DIR/Sources/Awareness.swift" \
  "$PROJECT_DIR/Tests/AwarenessLifecycleTests.swift" \
  -framework AppKit -framework ScreenCaptureKit -framework Vision \
  -o "$BUILD_DIR/AwarenessLifecycleTests"
"$BUILD_DIR/AwarenessLifecycleTests"

xcrun --sdk macosx swiftc \
  -swift-version 5 -parse-as-library -D PET_TESTING -target "$target" \
  "$PROJECT_DIR"/Sources/*.swift \
  "$PROJECT_DIR/Tests/PetRenderingTests.swift" \
  -framework AppKit -framework QuartzCore -framework ScreenCaptureKit -framework Vision \
  -o "$BUILD_DIR/PetRenderingTests"
"$BUILD_DIR/PetRenderingTests" "$PROJECT_DIR/Assets/pet.png"

skin_fixture="$PROJECT_DIR/Tests/CodexSkinConfigFixture.toml"
skin_test_dir=$(mktemp -d "${TMPDIR:-/tmp}/smile-skin-test.XXXXXX")
trap 'rm -r "$skin_test_dir"' EXIT
skin_config="$skin_test_dir/config.toml"
first_result="$skin_test_dir/first.toml"
cp "$skin_fixture" "$skin_config"
chmod 600 "$skin_config"

xcrun swift "$PROJECT_DIR/Tools/apply_codex_skin.swift" "$skin_config" >/dev/null
cp "$skin_config" "$first_result"
xcrun swift "$PROJECT_DIR/Tools/apply_codex_skin.swift" "$skin_config" >/dev/null

cmp -s "$first_result" "$skin_config"
[[ "$(stat -f %Lp "$skin_config")" == "600" ]]
grep -q '^model = "keep-me"$' "$skin_config"
grep -q '^untouched = "still-here"$' "$skin_config"
grep -q '^key = "value"$' "$skin_config"
[[ "$(grep -c '^selected-avatar-id = \"custom:xiaoxiao\"$' "$skin_config")" == "1" ]]
[[ "$(grep -c '^\[desktop\.appearanceDarkChromeTheme\]$' "$skin_config")" == "1" ]]
echo "Codex skin config: idempotent, unrelated settings preserved, mode 600."
