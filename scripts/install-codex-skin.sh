#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
CODEX_APP="/Applications/ChatGPT.app"
CODEX_CONFIG="$HOME/.codex/config.toml"
PET_DIR="$HOME/.codex/pets/xiaoxiao"
BACKUP_DIR="$HOME/.codex/theme-backups"
BACKUP_POINTER="$BACKUP_DIR/smile-skin-latest-backup"
SPRITESHEET="$PROJECT_DIR/CodexSkin/spritesheet.png"

if [[ ! -d "$CODEX_APP" ]]; then
  echo "Official Codex app not found at $CODEX_APP" >&2
  exit 1
fi
bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$CODEX_APP/Contents/Info.plist")
if [[ "$bundle_id" != "com.openai.codex" ]]; then
  echo "Unexpected bundle identifier: $bundle_id" >&2
  exit 1
fi
if [[ ! -f "$CODEX_CONFIG" ]]; then
  echo "Codex config not found at $CODEX_CONFIG" >&2
  exit 1
fi
if [[ ! -f "$SPRITESHEET" ]]; then
  echo "Missing Codex pet spritesheet" >&2
  exit 1
fi

width=$(sips -g pixelWidth "$SPRITESHEET" | awk '/pixelWidth/ {print $2}')
height=$(sips -g pixelHeight "$SPRITESHEET" | awk '/pixelHeight/ {print $2}')
alpha=$(sips -g hasAlpha "$SPRITESHEET" | awk '/hasAlpha/ {print $2}')
if [[ "$width" != "1536" || "$height" != "2288" || "$alpha" != "yes" ]]; then
  echo "Invalid spritesheet: expected 1536x2288 RGBA" >&2
  exit 1
fi

mkdir -p "$PET_DIR" "$BACKUP_DIR"
backup_path=""
if [[ -f "$BACKUP_POINTER" ]]; then
  existing_backup=$(<"$BACKUP_POINTER")
  case "$existing_backup" in
    "$BACKUP_DIR"/config-before-smile-skin-*.toml)
      if [[ -f "$existing_backup" ]]; then
        backup_path="$existing_backup"
      fi
      ;;
  esac
fi
if [[ -z "$backup_path" ]]; then
  timestamp=$(date -u +"%Y%m%dT%H%M%SZ")
  backup_path="$BACKUP_DIR/config-before-smile-skin-$timestamp.toml"
  cp -p "$CODEX_CONFIG" "$backup_path"
  print -r -- "$backup_path" > "$BACKUP_POINTER"
fi

install -m 0644 "$SPRITESHEET" "$PET_DIR/spritesheet.png"
install -m 0644 "$PROJECT_DIR/CodexSkin/pet.json" "$PET_DIR/pet.json"
xcrun swift "$PROJECT_DIR/Tools/apply_codex_skin.swift" "$CODEX_CONFIG"

echo "Installed Codex skin: 笑笑"
echo "Backup: $backup_path"
echo "Restart Codex if the pet does not refresh immediately."
