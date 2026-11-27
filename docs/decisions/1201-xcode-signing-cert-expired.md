# 1201: xcodebuild test hangs because Xcode 26.1.1's DTServiceHub certificate expired

Task 1225. Every `xcodebuild test` on this Mac hangs before running a test, so the `swift` suite times out at 1800 s. `build-for-testing` still works.

Cause: xcodebuild claims the local Mac for testing through DTServiceHub. dtarbiter rejects DTServiceHub's signature (OSStatus -67050, leaf and CA TemporalValidity) because both certificates expired on 2026-10-24. DTServiceHub exits, and xcodebuild blocks forever on the dead port.

Decision: no repository change. The owner installs a current Xcode 26.x and runs `xcode-select -s` on it. Verification: `xcodebuild test -skip-testing:DiskFreeUITests` gets past "Testing started".
