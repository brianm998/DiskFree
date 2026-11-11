#!/bin/bash
#
# Generate the App Store screenshots into docs/app-store/screenshots/.
#
# Builds the app and runs its binary with -renderScreenshots <dir>.  The app
# renders its demo-data views offscreen with SwiftUI ImageRenderer and exits;
# it never creates or shows a window.
#
# Usage: DiskFree/scripts/screenshots.sh

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$HERE/.." && pwd)"
REPO_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
OUT_DIR="$REPO_DIR/docs/app-store/screenshots"
ARGS=(-project "$PROJECT_DIR/DiskFree.xcodeproj" -scheme DiskFree -destination 'platform=macOS')

xcodebuild build "${ARGS[@]}"
PRODUCTS="$(xcodebuild -showBuildSettings "${ARGS[@]}" 2>/dev/null | awk -F' = ' '/^ *BUILT_PRODUCTS_DIR =/ {print $2; exit}')"

# The app is sandboxed and can only write inside its container, so it renders
# there and the script copies the PNGs into the repo.
STAGE="$HOME/Library/Containers/com.DiskFree/Data/tmp/screenshots"
rm -rf "$STAGE" "$OUT_DIR"
mkdir -p "$OUT_DIR"
"$PRODUCTS/DiskFree.app/Contents/MacOS/DiskFree" -renderScreenshots "$STAGE"
cp "$STAGE"/*.png "$OUT_DIR"/
rm -rf "$STAGE"

count=0
for f in "$OUT_DIR"/*.png; do
    w="$(sips -g pixelWidth "$f" | awk '/pixelWidth/ {print $2}')"
    h="$(sips -g pixelHeight "$f" | awk '/pixelHeight/ {print $2}')"
    [[ "$w" == 2880 && "$h" == 1800 ]] || { echo "$f is ${w}x${h}, expected 2880x1800" >&2; exit 1; }
    echo "ok $f"
    count=$((count + 1))
done
[[ "$count" -eq 3 ]] || { echo "expected 3 PNGs, found $count" >&2; exit 1; }
