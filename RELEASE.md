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
