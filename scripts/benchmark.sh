#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
BASE_REF="${1:-v1.4.1}"
DURATION="${2:-8}"
BUILD_DIR="$PROJECT_DIR/.build"
BASE_SHA=$(git -C "$PROJECT_DIR" rev-parse --verify --end-of-options "$BASE_REF^{commit}")
[[ "$DURATION" =~ '^[0-9]+$' ]] && (( DURATION >= 2 && DURATION <= 60 )) || {
  echo "Duration must be an integer from 2 to 60 seconds" >&2
  exit 1
}
case "$(uname -m)" in
  arm64) target="arm64-apple-macos13.0" ;;
  x86_64) target="x86_64-apple-macos13.0" ;;
  *) echo "Unsupported architecture" >&2; exit 1 ;;
esac
mkdir -p "$BUILD_DIR"
baseline_dir=$(mktemp -d "$BUILD_DIR/benchmark-baseline.XXXXXX")
trap 'rm -r "$baseline_dir"' EXIT
while IFS= read -r source; do
  [[ "$source" == *.swift ]] || continue
  git -C "$PROJECT_DIR" show "$BASE_SHA:$source" | sed '/^@main$/d' > "$baseline_dir/${source:t}"
done < <(git -C "$PROJECT_DIR" ls-tree -r --name-only "$BASE_SHA" -- Sources)

xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -O -D PET_TESTING \
  -target "$target" "$baseline_dir"/*.swift "$PROJECT_DIR/Tests/RenderBenchmark.swift" \
  -framework AppKit -framework QuartzCore -framework ScreenCaptureKit -framework Vision \
  -o "$BUILD_DIR/RenderBenchmark-baseline"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -O -D PET_TESTING \
  -target "$target" "$PROJECT_DIR"/Sources/*.swift "$PROJECT_DIR/Tests/RenderBenchmark.swift" \
  -framework AppKit -framework QuartzCore -framework ScreenCaptureKit -framework Vision \
  -o "$BUILD_DIR/RenderBenchmark"

baseline_results="$BUILD_DIR/benchmark-baseline.jsonl"
current_results="$BUILD_DIR/benchmark-current.jsonl"
: > "$baseline_results"
: > "$current_results"
for scenario in companion coding party hidden; do
  "$BUILD_DIR/RenderBenchmark-baseline" "$PROJECT_DIR/Assets/pet.png" "$scenario" "$DURATION" | tee -a "$baseline_results"
  "$BUILD_DIR/RenderBenchmark" "$PROJECT_DIR/Assets/pet.png" "$scenario" "$DURATION" | tee -a "$current_results"
done
echo "Baseline $BASE_SHA: $baseline_results"
echo "Current checkout: $current_results"
