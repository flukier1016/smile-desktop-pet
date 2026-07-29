#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"

failed=0
scan_files=()
while IFS= read -r -d '' tracked_path; do
  case "$tracked_path" in
    .env|*/.env|.env.*|*/.env.*|*.pem|*.key|*.p12|*.pfx|*.mobileprovision)
      echo "Forbidden sensitive file: $tracked_path" >&2
      failed=1
      ;;
    *.jpg|*.jpeg|*.heic|Assets/original*)
      echo "Potential source photo must not be tracked: $tracked_path" >&2
      failed=1
      ;;
  esac

  if [[ -f "$tracked_path" ]]; then
    size=$(stat -f %z "$tracked_path")
    if (( size > 12582912 )); then
      echo "Tracked file exceeds 12 MiB: $tracked_path" >&2
      failed=1
    fi

    case "$tracked_path" in
      scripts/security-check.sh|*.png|*.icns|*.dmg|*.zip)
        ;;
      *)
        scan_files+=("$tracked_path")
        ;;
    esac
  fi
done < <(git ls-files -z --cached --others --exclude-standard)

if (( failed != 0 )); then
  exit 1
fi

github_pattern='github'_'pat_[A-Za-z0-9_]{40,}|gh[pousr]_[A-Za-z0-9]{30,}'
openai_prefix='sk-'
openai_pattern="${openai_prefix}(proj-|live-)?[A-Za-z0-9_-]{24,}"
private_key_pattern='-----BEGIN[[:space:]][A-Z0-9[:space:]]*PRIVATE[[:space:]]KEY-----'

if (( ${#scan_files[@]} > 0 )) && LC_ALL=C grep \
  -E \
  -i \
  -n \
  -e "$github_pattern" \
  -e "$openai_pattern" \
  -e "$private_key_pattern" -- "${scan_files[@]}"; then
  echo "Possible credential or private key found." >&2
  exit 1
fi

network_pattern='URLSession|NWConnection|NWPathMonitor|CFNetwork|WebSocket|import[[:space:]]+Network'
if LC_ALL=C grep -R -E -n -e "$network_pattern" Sources; then
  echo "Network API found in app sources; update privacy and security review first." >&2
  exit 1
fi

for script in build.sh scripts/*.sh; do
  zsh -n "$script"
done

plutil -lint Info.plist >/dev/null
echo "Security check passed: no tracked secrets, source photos, or app network APIs."
