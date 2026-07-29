#!/bin/zsh
set -euo pipefail

CODEX_CONFIG="$HOME/.codex/config.toml"
PET_DIR="$HOME/.codex/pets/xiaoxiao"
BACKUP_DIR="$HOME/.codex/theme-backups"
BACKUP_POINTER="$BACKUP_DIR/smile-skin-latest-backup"

if [[ ! -f "$BACKUP_POINTER" ]]; then
  echo "No Smile skin backup pointer found." >&2
  exit 1
fi
backup_path=$(<"$BACKUP_POINTER")
case "$backup_path" in
  "$BACKUP_DIR"/config-before-smile-skin-*.toml) ;;
  *)
    echo "Refusing unexpected backup path: $backup_path" >&2
    exit 1
    ;;
esac
if [[ ! -f "$backup_path" ]]; then
  echo "Backup not found: $backup_path" >&2
  exit 1
fi

cp -p "$backup_path" "$CODEX_CONFIG"
if [[ -f "$PET_DIR/pet.json" ]]; then
  rm "$PET_DIR/pet.json"
fi
if [[ -f "$PET_DIR/spritesheet.png" ]]; then
  rm "$PET_DIR/spritesheet.png"
fi
rmdir "$PET_DIR" 2>/dev/null || true
rm "$BACKUP_POINTER"

echo "Restored Codex config: $backup_path"
echo "Restart Codex to finish restoring the previous appearance."
