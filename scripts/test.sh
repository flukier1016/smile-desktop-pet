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

xcrun --sdk macosx swiftc \
  -swift-version 5 \
  -parse-as-library \
  -target arm64-apple-macos13.0 \
  "$PROJECT_DIR/Sources/CompanionProgress.swift" \
  "$PROJECT_DIR/Tests/CompanionProgressTests.swift" \
  -o "$BUILD_DIR/CompanionProgressTests"

"$BUILD_DIR/CompanionProgressTests"

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
