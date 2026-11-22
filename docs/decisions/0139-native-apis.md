# 0139: native APIs instead of shell-outs

- Local volumes: `mountedVolumeURLs` with resource keys. Non-local and non-browsable volumes are skipped. Read-only volumes are listed (NTFS drives, write-locked cards, disks macOS remounted read-only) and marked "read-only" in the legend tooltip and Settings, except mounted disk images (DiskArbitration: device model "Disk Image" or protocol "Virtual Interface"), which are skipped as noise. `/` is always listed. The rule is the pure `LocalVolume.shouldList`.
- Network volumes: `getfsstat(MNT_NOWAIT)`; entries whose `f_mntfromname` starts with `//`.
- Free space: `statfs` cannot be killed when a SMB/AFP mount hangs. It runs on a global dispatch thread, raced against `dfTimeoutSeconds` via a once-only continuation; a timeout counts as no data. At most one probe per mount is in flight, so a hung mount holds one thread, and the timeout bounds the poll, not the syscall.
- Speech: `NSSpeechSynthesizer`, not `AVSpeechSynthesizer`, since most `Voice` cases are novelty voices AVSpeech does not expose. Voices are matched by name against `availableVoices`; default voice if missing.
