#!/bin/bash

set -e

# Build and notarize the DiskFree app for Developer ID distribution.
#
# Local usage (uses keychain profile "diskfree"):
#   ./release.sh --version 0.8.1 --notarize
#
# CI usage (uses App Store Connect API key from env vars):
#   ./release.sh --version 0.8.1 --sign "Developer ID Application: ..." --notarize
#
# Required env vars in CI (when --notarize is passed with --sign):
#   APPLE_TEAM_ID, APPLE_API_KEY_PATH, APPLE_API_KEY_ID, APPLE_API_ISSUER_ID

BUILD_DIR=.build
APP_NAME=DiskFree
VERSION="0.8.0"
SIGN_IDENTITY=""
NOTARIZE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --version)  VERSION="$2";       shift 2 ;;
        --sign)     SIGN_IDENTITY="$2"; shift 2 ;;
        --notarize) NOTARIZE=true;      shift ;;
        --out)      BUILD_DIR="$2";     shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

PKG_NAME="${BUILD_DIR}/disk_free_${VERSION}.pkg"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# stamp version into project
perl -pi -e "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = ${VERSION}/" DiskFree.xcodeproj/project.pbxproj
perl -pi -e "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = ${VERSION}/" DiskFree.xcodeproj/project.pbxproj

# CI passes --sign to use manual signing with the imported cert; local builds
# use the project's automatic signing with the developer's own keychain.
CODE_SIGN_FLAGS=()
if [[ -n "$SIGN_IDENTITY" ]]; then
    CODE_SIGN_FLAGS+=(
        "CODE_SIGN_STYLE=Manual"
        "CODE_SIGN_IDENTITY=${SIGN_IDENTITY}"
        "DEVELOPMENT_TEAM=${APPLE_TEAM_ID}"
        "OTHER_CODE_SIGN_FLAGS=--timestamp --options=runtime"
    )
fi

xcodebuild \
    -project "DiskFree.xcodeproj" \
    -scheme "DiskFree" \
    -configuration "Release" \
    -destination "generic/platform=macOS" \
    -archivePath "${BUILD_DIR}/DiskFree.xcarchive" \
    ONLY_ACTIVE_ARCH=NO \
    "ARCHS=arm64 x86_64" \
    "${CODE_SIGN_FLAGS[@]}" \
    archive

if [[ -n "$SIGN_IDENTITY" ]]; then
    cat > "${BUILD_DIR}/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
    <key>teamID</key>
    <string>${APPLE_TEAM_ID}</string>
</dict>
</plist>
PLIST
else
    cat > "${BUILD_DIR}/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
PLIST
fi

echo "exporting archive"

xcodebuild \
    -exportArchive \
    -archivePath "${BUILD_DIR}/DiskFree.xcarchive" \
    -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" \
    -exportPath "${BUILD_DIR}/AdHoc"

ditto \
    -c -k --sequesterRsrc --keepParent \
    "${BUILD_DIR}/AdHoc/${APP_NAME}.app" \
    "${BUILD_DIR}/${APP_NAME}-for-notarization.zip"

notarize_submit() {
    local target="$1"
    if [[ -n "$APPLE_API_KEY_PATH" && -n "$APPLE_API_KEY_ID" && -n "$APPLE_API_ISSUER_ID" ]]; then
        xcrun notarytool submit "$target" \
              --key "$APPLE_API_KEY_PATH" \
              --key-id "$APPLE_API_KEY_ID" \
              --issuer "$APPLE_API_ISSUER_ID" \
              --wait
    else
        xcrun notarytool submit "$target" \
              --keychain-profile "diskfree" \
              --wait
    fi
}

if $NOTARIZE; then
    notarize_submit "${BUILD_DIR}/${APP_NAME}-for-notarization.zip"
    xcrun stapler staple "${BUILD_DIR}/AdHoc/${APP_NAME}.app"
fi

# Derive pkg signing identity from app signing identity when available
if [[ -n "$SIGN_IDENTITY" ]]; then
    PKG_SIGN_IDENTITY="${SIGN_IDENTITY/Developer ID Application/Developer ID Installer}"
    PKG_SIGN_ARG=(--sign "$PKG_SIGN_IDENTITY")
else
    PKG_SIGN_ARG=(--sign "Developer ID Installer: Brian Martin (G3L75S65V9)")
fi

pkgbuild \
    --root "${BUILD_DIR}/AdHoc/${APP_NAME}.app" \
    --identifier com.diskfree \
    --version "${VERSION}" \
    --install-location "/Applications/${APP_NAME}.app" \
    "${PKG_SIGN_ARG[@]}" \
    "$PKG_NAME"

if $NOTARIZE; then
    notarize_submit "$PKG_NAME"
    xcrun stapler staple "$PKG_NAME"
fi

echo "signed, notarized and stapled results packaged up in ${PKG_NAME}"
