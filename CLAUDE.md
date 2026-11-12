# DiskFree

@AGENTS.md

## Nothing runs on the Mac's screen

Never run `DiskFreeUITests` (or any `xcodebuild test` that executes a `*UITests` bundle) from a
shell. XCUITest drives the real mouse and keyboard and puts the dimmed "Automation Running" overlay
over the owner's screen. The pipeline's test suite skips that bundle on purpose, and under MASON an
`xcodebuild` shim refuses such runs (exit 69). Don't work around that with `caffeinate -u`, an
on-screen window, or `screencapture` either.

Screenshots, including App Store ones, are rendered offscreen: `ImageRenderer`, the app's
`-renderScreenshots` mode, and the `.prohibited` activation policy. That is how #158 produced them
after #155 was stopped for using XCUITest.
