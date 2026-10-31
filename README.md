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

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/aleksandargosevski/matrix-overlay/main/install.sh | zsh
```

Clones to `~/.local/share/matrix-overlay`, builds, creates the config and installs the idle
agent. Run the same command again to update. Env options: `MATRIX_IDLE=120` (writes
`idle_seconds`, `0` = no idle agent), `MATRIX_DIR=~/somewhere`.

## Animations

* **rain**: classic digital rain with katakana, glowing heads and fading trails
* **typer**: black screen, someone "hand-types" code: uneven rhythm, thinking pauses,
  auto-indent, typos fixed with backspace, blinking block cursor. The text comes from
  `typer.txt` (snippets separated by a line containing only `---`). Put in your own
  pseudo-code, song lyrics, anything.
* **random**: picks one each time

## Config

`~/.config/matrix-overlay/config.toml` (created on install, hot-reloaded, no restart needed):

```toml
animation = "random"      # "rain" | "typer" | "random"
idle_seconds = 60
media_check = true
color = "#00ff41"
opacity = 0.92
fps = 30

[rain]
font_size = 16

[typer]
font = ""                 # empty = SF Mono
font_size = 18
text_file = "~/.config/matrix-overlay/typer.txt"
chars_per_second = 14
typo_rate = 0.02
loop = true
opacity = 1.0
```

## CLI

```bash
bin/matrix-overlay                      # show once, dismiss with any input
bin/matrix-overlay --animation typer    # override animation
bin/matrix-overlay --daemon             # idle mode (what the launchd agent runs)
bin/matrix-overlay --init-config        # create default config + typer.txt if missing
```

Other overrides: `--idle <sec>`, `--size <pt>`, `--opacity <0-1>`, `--no-media-check`,
`--config <path>`.

Scripts: `scripts/build.sh`, `scripts/install.sh [idle_seconds]`, `scripts/uninstall.sh`.
Logs: `$TMPDIR/matrix-overlay.log`.

## Raycast

Add `raycast/` as a Script Directory (Settings → Extensions → + → Add Script Directory):

* **Matrix**: show now, with optional animation dropdown. Assign a hotkey.
* **Toggle Matrix Idle**: pause/resume the idle agent
* **Edit Matrix Config**: opens `config.toml` and `typer.txt`

## How media detection works

Before showing on idle, `pmset -g assertions` is checked. Any display-sleep or WebRTC/call
assertion held by a process other than keep-awake tools (`caffeinate`, Raycast,
Amphetamine, KeepingYouAwake, Lungo, Theine) blocks the trigger.
