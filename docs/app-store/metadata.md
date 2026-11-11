# Disk Free — App Store Connect metadata

Source text for the App Store listing, to paste into App Store Connect. Each field shows its limit and its actual character count (`count / limit`).

## App information

| Field | Value | Count / limit |
|---|---|---|
| Name | Disk Free | 9 / 30 |
| Name (fallback if taken) | Disk Free – Volume Monitor | 26 / 30 |
| Subtitle | Free space on every volume | 26 / 30 |
| Category | Utilities | n/a |
| Price | Free | n/a |
| Privacy policy URL | https://github.com/brianm998/DiskFree/blob/main/docs/privacy.md | n/a |
| Support URL | https://github.com/brianm998/DiskFree/issues | n/a |
| Marketing URL | https://github.com/brianm998/DiskFree | n/a |

## Promotional text (147 / 170)

Watch free space on every local and network volume in real time. Live charts, colour-coded fullness and spoken low-space alerts. No data collected.

## Keywords (85 / 100)

disk,free space,storage,volume,monitor,network,SMB,drive,capacity,alert,chart,SSD,NAS

## Description (1512 / 4000)

Disk Free shows you how much free space every volume on your Mac has, live, so you notice a filling disk before it becomes a problem.

VOLUME MONITORING
• Tracks free and used space on all mounted local volumes: internal, external and ejectable
• Supports network volumes over SMB and AFP, queried in parallel with a timeout so a slow share never hangs the app
• Configurable polling: local volumes every 4 seconds and network volumes every 30 seconds by default
• Keeps a configurable window of history (60 minutes by default) and reloads it on the next launch

CHARTS
• Line charts of free and used space over time
• Combined layout (all volumes in one chart) or Separate layout (one chart per volume)
• Turn the free-space and used-space traces on and off independently
• Volumes are colour-coded by fullness, from blue when empty to red as they fill up
• Adjustable legend font size

SPOKEN ALERTS
• Hear a warning when free space on any volume drops below a threshold you choose (100 GB by default)
• Hear an error at a second, lower threshold (20 GB by default)
• Pick a different macOS voice for warnings and for errors
• Alerts fire when a threshold is crossed, not continuously

SETTINGS
• Choose which local and network volumes to show
• Select All and Clear All shortcuts for the local volume list

PRIVATE BY DESIGN
Disk Free collects no data and has no network access of its own. History and settings stay on your Mac, and spoken alerts use macOS speech locally.

Disk Free is free and open source.

## Screenshots

`docs/app-store/screenshots/` (2880×1800, demo data only; regenerate with `DiskFree/scripts/screenshots.sh`).

## Age rating

All questions answered **None**: cartoon or fantasy violence, realistic violence, sexual content or nudity, profanity or crude humor, alcohol/tobacco/drug references, mature/suggestive themes, horror/fear themes, medical/treatment information, gambling and contests; unrestricted web access: No. Resulting rating: 4+.

## App Privacy

**Data Not Collected.** Disk Free collects no data from the user (see `docs/privacy.md`).

## Export compliance

The app uses no non-exempt encryption. It has no network access of its own and implements no cryptography. Answer "No" to the encryption question (equivalently, `ITSAppUsesNonExemptEncryption` = NO).

## Review notes (677 / 4000)

Disk Free has no sign-in and no demo account. Launch it and it immediately lists the volumes mounted on the Mac.

Network volumes: the app does not connect to anything itself. It reads the free space of SMB/AFP shares that are already mounted in Finder. If the reviewer has none mounted, only local volumes appear, and that is expected.

Spoken alerts: when free space on a volume drops below a threshold (Settings > Audio), the app speaks a warning using the macOS speech synthesizer, locally. They are off until enabled in Settings and can be tested with the Test button there. No audio or text leaves the Mac.

The app collects no data and uses no network access of its own.
