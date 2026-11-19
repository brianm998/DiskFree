# 0615 Expired switches finding (task 603)

Searched the repo for feature flags, expiry dates, sunset or remove-after markers. The only matches are SwiftUI `Toggle` user preferences and Swift `switch` statements. The app has no time-limited switches in code.

Decision: no code change. The switches in finding 18 are not in this repository (likely MASON pipeline configuration). The owner should close them where they are defined.
