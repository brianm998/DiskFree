#!/bin/bash
#
# Generate the App Store screenshots into docs/app-store/screenshots/.
#
# Runs DiskFreeUITests/ScreenshotTests (the app is launched with
# -screenshotMode, which shows demo volumes only), pulls the screenshot
# attachments out of the .xcresult, and scales + pads each to 2880x1800.
#
# Usage: DiskFree/scripts/screenshots.sh [--direct]
#
#   --direct  skip XCUITest: build the app, launch it three times with the
#             demo arguments and capture its window with screencapture.  Use
#             this when the UI test runner cannot reach the app's window
#             (e.g. a session where accessibility is unavailable).

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$HERE/.." && pwd)"
OUT_DIR="$(cd "$PROJECT_DIR/.." && pwd)/docs/app-store/screenshots"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

WIDTH=2880
HEIGHT=1800

mkdir -p "$OUT_DIR"

# Scale + pad every NN-*.png in $1 to exactly WIDTH x HEIGHT into $OUT_DIR.
finish_dir() {
    python3 -I - "$1" "$OUT_DIR" "$WIDTH" "$HEIGHT" <<'PY'
import os, subprocess, sys

src_dir, out, width, height = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])

def dims(path):
    info = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", path]).decode()
    vals = {l.split(":")[0].strip(): int(l.split(":")[1]) for l in info.splitlines() if ":" in l and "pixel" in l}
    return vals["pixelWidth"], vals["pixelHeight"]

found = {}
for name in sorted(os.listdir(src_dir)):
    if name.endswith(".png") and name[:2].isdigit():
        found[name.split("_")[0].removesuffix(".png")] = os.path.join(src_dir, name)
if len(found) < 3:
    sys.exit("expected at least 3 screenshots, found %d" % len(found))
for stem, src in sorted(found.items()):
    dst = os.path.join(out, stem + ".png")
    w, h = dims(src)
    scale = min(width / w, height / h)
    nw, nh = min(width, round(w * scale)), min(height, round(h * scale))
    # scale to fit within width x height, then pad to exactly that size
    subprocess.check_call(["sips", "--resampleHeightWidth", str(nh), str(nw), src, "--out", dst],
                          stdout=subprocess.DEVNULL)
    subprocess.check_call(["sips", "--padToHeightWidth", str(height), str(width),
                           "--padColor", "ECECEC", dst], stdout=subprocess.DEVNULL)
    if dims(dst) != (width, height):
        sys.exit("%s is %dx%d, expected %dx%d" % ((dst,) + dims(dst) + (width, height)))
    print("wrote", dst)
PY
}

if [[ "${1:-}" == "--direct" ]]; then
    DERIVED="$WORK/derived"
    xcodebuild build -project "$PROJECT_DIR/DiskFree.xcodeproj" -scheme DiskFree \
        -destination 'platform=macOS' -derivedDataPath "$DERIVED"
    APP="$DERIVED/Build/Products/Debug/DiskFree.app/Contents/MacOS/DiskFree"
    SHOTS="$WORK/shots"
    mkdir -p "$SHOTS"
    cat > "$WORK/winid.swift" <<'SW'
import CoreGraphics
let pid = Int32(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == pid && (w[kCGWindowLayer as String] as? Int) == 0 {
    print(w[kCGWindowNumber as String] as! Int); break
}
SW
    shoot() { # name, extra args...
        local name="$1"; shift
        "$APP" -screenshotMode \
            "-NSWindow Frame DiskFree.ContentView-1-AppWindow-1" "300 300 1440 900 0 0 2560 1415" \
            -ApplePersistenceIgnoreState YES "$@" &
        local pid=$!
        local id=""
        for _ in $(seq 1 30); do
            sleep 1
            id="$(swift "$WORK/winid.swift" "$pid" 2>/dev/null || true)"
            [[ -n "$id" ]] && break
        done
        [[ -n "$id" ]] || { kill "$pid"; echo "no window for $name" >&2; exit 1; }
        sleep 3
        screencapture -x -o -l "$id" "$SHOTS/$name.png"
        kill "$pid"; wait "$pid" 2>/dev/null || true
    }
    shoot 01-combined -screenshotLayout combined
    shoot 02-separate -screenshotLayout separate
    shoot 03-settings -screenshotLayout combined -screenshotSettings
    finish_dir "$SHOTS"
    exit 0
fi

RESULT="$WORK/result.xcresult"

xcodebuild test \
    -project "$PROJECT_DIR/DiskFree.xcodeproj" \
    -scheme DiskFree \
    -destination 'platform=macOS' \
    -only-testing:DiskFreeUITests/ScreenshotTests \
    -resultBundlePath "$RESULT"

EXPORT="$WORK/attachments"
mkdir -p "$EXPORT"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$EXPORT"

# attachments are named NN-<layout>; xcresulttool exports them under uuid file
# names, with manifest.json giving the attachment names
python3 -I - "$EXPORT" <<'PY'
import json, os, shutil, sys
export = sys.argv[1]
with open(os.path.join(export, "manifest.json")) as f:
    manifest = json.load(f)
for test in manifest:
    for att in test.get("attachments", []):
        suggested = att.get("suggestedHumanReadableName", "")
        if suggested[:2].isdigit():
            shutil.copy(os.path.join(export, att["exportedFileName"]),
                        os.path.join(export, suggested.split("_")[0] + ".png"))
PY
finish_dir "$EXPORT"
