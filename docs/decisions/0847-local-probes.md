# 0847 Probe local volumes off the actor, with statfs

Each local volume is probed on a background thread raced against a 5 s timeout, one probe in flight per volume key, all volumes in parallel. Every poll uses `statfs`; the important/opportunistic figures are refreshed at most once a minute per volume and their offset from statfs is applied in between. A probe whose `f_mntonname` differs from the mount point, or whose volume UUID differs, records nothing and requests a re-list.
