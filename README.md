# matrix-overlay

Native Matrix digital rain overlay for macOS. It covers all displays like a
screensaver, but it is just a transparent window, so it works even when the Mac
is kept awake by `caffeinate`, Raycast Coffee or Amphetamine.

* Katakana glyphs, glowing heads, 12-step green fade, per-display windows
* Fades in, dismisses on any mouse/keyboard input and returns focus to the previous app
* Idle trigger reads HID idle time directly (not affected by keep-awake tools)
* Skips the idle trigger while the screen is locked, while video is playing or during
  calls (YouTube, Meet, Zoom, Teams, FaceTime, Slack, Discord, Webex)

## Requirements

macOS 13+ and Xcode Command Line Tools (`xcode-select --install`).

## Usage

```bash
scripts/build.sh                 # builds bin/matrix-overlay
bin/matrix-overlay               # show once, dismiss with any input
scripts/install.sh 60            # launchd agent: show after 60 s idle
scripts/install.sh 120 --opacity 0.7 --size 20
scripts/uninstall.sh
```

Options: `--idle <sec>`, `--size <pt>` (default 16), `--opacity <0-1>` (default 0.92),
`--no-media-check`.

Logs (skipped triggers and reasons): `$TMPDIR/matrix-overlay.log`

## Raycast

Add `raycast/` as a Script Directory (Settings → Extensions → + → Add Script Directory)
and assign a hotkey to **Matrix**. **Toggle Matrix Idle** pauses/resumes the idle agent.

## How media detection works

Before showing on idle, `pmset -g assertions` is checked. Any display-sleep or WebRTC/call
assertion held by a process other than keep-awake tools (`caffeinate`, Raycast,
Amphetamine, KeepingYouAwake, Lungo, Theine) blocks the trigger.
