# Audio cues

Omarchy's desktop notification tool (`omarchy-notification-send`) is a
visual toast only — it has no way to attach a custom sound, so distinct
per-event audio has to be played by the plugin itself, decoupled from the
notification.

These are short, synthesized WAV files (generated with a small Python
script using the stdlib `wave` module — no external assets, no licensing
concerns) played via `paplay` from `BarWidget.qml`'s `playCue()`:

| File          | Used for                                      |
|---------------|------------------------------------------------|
| `minute.wav`  | Every minute mark                              |
| `warning.wav` | Each of the last 5 seconds of a minute         |
| `go.wav`      | Workout start                                  |
| `done.wav`    | Workout complete                               |

A visual notification fires alongside every cue (see `notify()` in
`BarWidget.qml`), so the workout stays trackable with sound muted or the
bar out of view.

## Regenerating

```
python3 - <<'PY'
# see the generator used to create these files; tweak freq/dur/envelope
# as needed and re-run to replace sounds/*.wav
PY
```

Swap in real recorded cues instead by dropping same-named `.wav` files in
this directory — nothing else needs to change.
