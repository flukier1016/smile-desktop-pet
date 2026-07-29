#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
VERSION="${1:-1.3.0}"
APP_NAME="笑笑桌宠"
DIST_DIR="$PROJECT_DIR/dist"
STAGE_DIR="$DIST_DIR/$APP_NAME-v$VERSION"
ZIP_PATH="$DIST_DIR/SmilePet-v$VERSION-macos-universal.zip"
DMG_PATH="$DIST_DIR/SmilePet-v$VERSION-macos-universal.dmg"
CHECKSUM_PATH="$DIST_DIR/SHA256SUMS.txt"

if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$' ]]; then
  echo "Invalid version: $VERSION" >&2
  exit 1
fi

PLIST_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PROJECT_DIR/Info.plist")
if [[ "$PLIST_VERSION" != "$VERSION" ]]; then
  echo "Version mismatch: Info.plist=$PLIST_VERSION requested=$VERSION" >&2
  exit 1
fi

"$PROJECT_DIR/scripts/security-check.sh"
"$PROJECT_DIR/scripts/test.sh"
"$PROJECT_DIR/build.sh"
mkdir -p "$DIST_DIR"

if [[ -d "$STAGE_DIR" ]]; then
  rm -r "$STAGE_DIR"
fi
mkdir -p "$STAGE_DIR"
cp -R "$PROJECT_DIR/$APP_NAME.app" "$STAGE_DIR/"
cp "$PROJECT_DIR/开始使用.txt" "$STAGE_DIR/"
cp "$PROJECT_DIR/MANUAL.md" "$STAGE_DIR/用户使用手册.md"
cp "$PROJECT_DIR/PRIVACY.md" "$STAGE_DIR/隐私说明.md"
cp "$PROJECT_DIR/LICENSE" "$STAGE_DIR/LICENSE.txt"
ln -s /Applications "$STAGE_DIR/Applications"

rm -f "$ZIP_PATH" "$DMG_PATH" "$CHECKSUM_PATH"
COPYFILE_DISABLE=1 ditto -c -k --sequesterRsrc --keepParent "$STAGE_DIR" "$ZIP_PATH"
hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

(
  cd "$DIST_DIR"
  shasum -a 256 "${ZIP_PATH:t}" "${DMG_PATH:t}" > "${CHECKSUM_PATH:t}"
)

rm -r "$STAGE_DIR"

echo "Release artifacts:"
ls -lh "$ZIP_PATH" "$DMG_PATH" "$CHECKSUM_PATH"
