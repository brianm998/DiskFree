# Disk Free — Release Notes

## 0.1.0 — Initial Release

First public release of Disk Free, a free and open-source macOS app for monitoring
free space across local and network volumes in real time.

### Features

**Volume monitoring**
- Tracks free and used space on all mounted local volumes (internal, external, ejectable)
- Supports network volumes over SMB and AFP, queried in parallel with a timeout to avoid hangs
- Configurable polling intervals — local volumes default to every 4 seconds, network volumes every 30 seconds
- Historical data retained for a configurable window (default: 60 minutes) and reloaded on next launch

**Charts**
- Line charts showing free/used space trends over time
- Two layouts: *Combined* (all volumes in one chart) or *Separate* (one chart per volume)
- Toggle free-space and used-space traces independently
- Volumes are colour-coded by fullness — blue when empty, shifting to red as they fill up
- Adjustable legend font size

**Audio alerts**
- Spoken warnings when free space on any volume drops below a configurable threshold (default: 100 GB)
- Spoken errors at a second, lower threshold (default: 20 GB)
- Independent voice selection for warnings and errors
- Alerts fire only on threshold crossings, not continuously

**Settings**
- Per-volume opt-in/opt-out for both local and network volumes
- Select All / Clear All shortcuts for local volume list
- All settings and historical records persist to the Documents folder as JSON

### Requirements

- macOS 15.0 or later

## App Store

The `app-store` job in `.github/workflows/release.yml` builds a Mac App Store
package (`disk_free_<version>_mas.pkg`, artifact `disk-free-mas`) with
`./release.sh --app-store` and uploads it to App Store Connect with
`xcrun altool`. It does not notarize. Until `MAS_CERTIFICATE_P12_BASE64` exists
the job logs a notice and exits 0, so tag pushes keep working.

On a manual run, the `upload_to_app_store` input (default off) controls whether
the build is uploaded; when off, it is built and validated only.

### GitHub secrets (added by hand)

- `MAS_CERTIFICATE_P12_BASE64` — one .p12 containing both the Apple Distribution
  and the Mac Installer Distribution (3rd Party Mac Developer Installer) identities
- `MAS_CERTIFICATE_PASSWORD` — password of that .p12
- `MAS_PROVISIONING_PROFILE_BASE64` — the Mac App Store provisioning profile for `com.DiskFree`
- Reused from the Developer ID path: `APPLE_TEAM_ID`, `KEYCHAIN_PASSWORD`,
  `APPLE_API_KEY_P8_BASE64`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`
  (the API key needs the App Manager or Admin role)

### Manual App Store Connect steps

1. Register the App ID `com.DiskFree` (Certificates, Identifiers & Profiles).
2. Create the app record in App Store Connect (name, bundle ID, SKU, category, privacy details, screenshots).
3. Run the release workflow so the build uploads; wait for processing to finish.
4. In App Store Connect, select the uploaded build on the version page and submit it for review.
