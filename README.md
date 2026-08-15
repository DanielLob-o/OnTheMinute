# OnTheMinute

A customizable EMOM (Every Minute On the Minute) workout timer, built as an
[Omarchy](https://github.com/basecamp/omarchy) shell plugin.

Write the exercises you want to cycle through, set how many minutes to go,
and start the clock. OnTheMinute cues you every minute and again in the
last 5 seconds of each minute, and keeps a history of finished sessions.

## Features

- **Customizable workout** — any list of exercises, one per line, and any
  number of minutes.
- **Two ways to watch it**: a compact countdown in the bar with a dropdown
  to configure and control it, or a fullscreen "big screen" view for when
  you want the timer visible from across the room.
- **Audio + visual cues** — a distinct sound on every minute mark and on
  each of the last 5 seconds, plus a desktop notification alongside every
  cue so the workout stays trackable even muted or off-screen.
- **Session history** — every completed workout (exercises, minute count,
  finish time) is saved locally.

## Install

```bash
omarchy plugin add https://github.com/DanielLob-o/OnTheMinute.git --enable --yes
```

Or by hand:

```bash
git clone https://github.com/DanielLob-o/OnTheMinute.git ~/.config/omarchy/plugins/lobo.on-the-minute
omarchy-shell shell rescanPlugins
omarchy plugin enable lobo.on-the-minute
```

## Usage

- Click the bar widget to open the configuration dropdown: enter exercises
  (one per line) and a minute count, then hit start.
- Right-click the bar widget, or use the dropdown's expand button, to open
  the fullscreen big view. `Esc` closes it.
- Toggle sound on/off from the dropdown.

## License

MIT — see [`LICENSE`](LICENSE).
