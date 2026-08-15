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
  cue so the workout stays trackable even muted or off-screen. See
  [`sounds/README.md`](sounds/README.md) for why cues are bundled and
  played directly rather than riding on the desktop notification.
- **Session history** — every completed workout (exercises, minute count,
  finish time) is saved to
  `~/.local/state/omarchy/on-the-minute-history.json`.

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

## Project structure

```
manifest.json    plugin manifest (bar-widget + overlay)
BarWidget.qml    bar label + timer state + persistence + notifications/sound
Panel.qml        dropdown: exercise/minute editing, transport, history
Overlay.qml      fullscreen big-view surface
Model.js         pure workout math (exercise parsing, countdown formatting)
History.js       pure session-history math (parse/add/remove/clear)
sounds/          bundled audio cues + generation notes
```

Settings (exercises, minutes, sound on/off) persist inline in
`~/.config/omarchy/shell.json` against the widget's entry, the same way the
built-in clock widget persists its format. Session history is unbounded and
lives in its own state file instead, the same pattern the built-in
clipboard manager uses for clipboard history.

## Status

Scaffolded and structurally valid (`omarchy plugin validate`-ready): the
manifest, file layout, persistence design, and audio design are settled,
and the core timer/notification/history logic in `BarWidget.qml` is wired
up. Still open before a first real release:

- [ ] Verify the actual `qs.Commons`/`qs.Ui` component API surface used here
      (`WidgetButton`, `KeyboardPanel`, `PanelKeyCatcher`, `PanelActionButton`,
      `BarWidget`/`Panel` base types) against a running `omarchy-shell` —
      written from reading the built-in plugins' source, not yet run live.
- [ ] Per-second warning cue during the last 5 seconds (currently fires once
      per minute-boundary check; needs a sub-tick or a dedicated countdown
      timer for 5/4/3/2/1).
- [ ] Resolve the plugin's own directory for `playCue()` instead of a
      relative `sounds/` path, and fall back to `pw-play` if `paplay` isn't
      on the system.
- [ ] Overlay should read live state from the bar widget instance rather
      than a placeholder copy.
- [ ] Scrollable/paginated history list once entries pile up.
- [ ] `preview.png` for the marketplace listing.

## License

MIT — see [`LICENSE`](LICENSE).
