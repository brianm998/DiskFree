# 0840 Key local volumes by UUID

`LocalVolume.key` is the volume UUID string, else the real mount point; equality, records, hidden sets and alert sets use it (`VolumeType.key`). `name` is for display and speech only. Stored name keys migrate to the key when exactly one mounted volume has that name; other name-like entries are dropped, while UUID/path-like entries are kept for unplugged drives.
