import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "History.js" as History

// Bar label for the EMOM timer, and the host for both the configuration
// dropdown (Panel.qml) and the fullscreen "big screen" view (Overlay.qml).
// Timer state lives here rather than in the panel/overlay because those are
// only loaded while summoned — the countdown has to keep running, and the
// bar label has to keep updating, whether either surface is open or not.
//
// The overlay is a separately-summoned top-level plugin surface with no
// direct reference to this instance, so live state reaches it through a
// small watched state file (liveStatePath below) rather than a shared
// service singleton — Quickshell's synchronous service-plugin loader
// (shell.serviceFor/ensureService) reliably fails third-party services with
// a spurious "File name case mismatch" here, reproduced even with a plain,
// non-symlinked plugin directory, so that path is avoided.
BarWidget {
  id: root
  moduleName: "lobo.on-the-minute"

  // ---- Configuration. Persisted inline in shell.json (see Panel.qml's
  //      persistSettings), same pattern the clock widget uses for its
  //      birthYear/lifeExpectancy fields.
  readonly property string exercisesText: setting("exercisesText", "")
  readonly property var exercises: Model.parseExercises(exercisesText)
  readonly property int configuredMinutes: Model.validMinutes(setting("minutes", Model.DEFAULT_MINUTES))
  readonly property bool soundEnabled: setting("soundEnabled", true)

  readonly property string exercisesLabel: Model.exercisesLabel(root.exercises)

  // ---- Session history. Own state file, not a shell.json setting — this
  //      grows unbounded over time, same reasoning as clipboard history.
  property var history: []
  readonly property string historyPath: Quickshell.env("HOME") + "/.local/state/omarchy/on-the-minute-history.json"
  readonly property int historyLimit: 200

  FileView {
    id: historyFile
    path: root.historyPath
    // A fresh install has no history file yet — that's expected, not an
    // error, so it resolves to an empty history rather than surfacing a
    // load failure. Mirrors clipboard's FileView.onLoadFailed.
    onLoaded: root.history = History.parseHistory(text())
    onLoadFailed: root.history = History.parseHistory("[]")
  }

  function saveHistory() {
    historyFile.setText(JSON.stringify(root.history, null, 2) + "\n")
  }

  function deleteHistoryEntry(index) {
    root.history = History.removeAt(root.history, index)
    saveHistory()
  }

  function recordSession() {
    root.history = History.addSession(root.history, {
      finishedAt: new Date().toISOString(),
      minutes: root.configuredMinutes,
      exercises: root.exercises
    }, root.historyLimit)
    saveHistory()
  }

  // ---- Live countdown state. Transient — a restart of the shell should not
  //      try to resume mid-workout.
  property bool running: false
  property bool paused: false
  property int minuteIndex: 0                        // whole minutes elapsed since start
  property int secondsLeft: Model.INITIAL_SECONDS_LEFT // counts down within the current minute

  function resetCountdown() {
    root.minuteIndex = 0
    root.secondsLeft = Model.INITIAL_SECONDS_LEFT
  }

  readonly property string displayText: root.running
    ? Model.formatClock(root.configuredMinutes - root.minuteIndex - 1, root.secondsLeft)
    : "EMOM"

  // ---- Live state file for Overlay.qml. Written on every state change
  //      rather than polled; Overlay.qml watches it with FileView's
  //      watchChanges, the same "write, watch, react" shape the image
  //      picker uses for its selection round-trip.
  readonly property string liveStatePath: Quickshell.env("HOME") + "/.local/state/omarchy/on-the-minute-live.json"

  FileView { id: liveStateFile; path: root.liveStatePath }

  function publishLiveState() {
    liveStateFile.setText(JSON.stringify({
      running: root.running,
      displayText: root.displayText,
      exercisesLabel: root.exercisesLabel,
      exercises: root.exercises
    }))
  }

  function start() {
    if (!Model.canStart(root.exercises, root.configuredMinutes)) return
    root.running = true
    root.paused = false
    resetCountdown()
    notify("EMOM started", root.exercisesLabel)
    playCue("go")
    publishLiveState()
  }

  // Pausing only flips a local flag the Timer checks (see below) — nothing
  // in the published live state depends on it, so no publish is needed.
  function pause() {
    if (!root.running) return
    root.paused = !root.paused
  }

  function reset() {
    root.running = false
    root.paused = false
    resetCountdown()
    publishLiveState()
  }

  // Mutually exclusive by construction (see Model.isWarningPhase): the
  // last-5-seconds ticks and the minute landmark never land on the same
  // second, so exactly one branch below runs per tick, and each one
  // publishes exactly once.
  function tick() {
    if (!root.running || root.paused) return

    if (Model.isWarningPhase(root.secondsLeft)) {
      playCue("warning")
      root.secondsLeft -= 1
    } else if (Model.isMinuteLandmark(root.secondsLeft)) {
      root.minuteIndex += 1
      if (root.minuteIndex >= root.configuredMinutes) {
        root.running = false
        recordSession()
        notify("EMOM complete", Model.completionMessage(root.configuredMinutes))
        playCue("done")
      } else {
        root.secondsLeft = Model.INITIAL_SECONDS_LEFT
        notify("Minute " + (root.minuteIndex + 1), root.exercisesLabel)
        playCue("minute")
      }
    } else {
      root.secondsLeft -= 1
    }

    publishLiveState()
  }

  Timer {
    interval: 1000
    running: root.running
    repeat: true
    onTriggered: root.tick()
  }

  // ---- Notifications + sound. Desktop toast for visibility when the bar
  //      isn't in view, bundled audio cues (see sounds/README.md) played
  //      independently via paplay/pw-play so each event gets a distinct,
  //      reliable sound regardless of the system notification theme.
  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  function notify(headline, body) {
    Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-notification-send", "--app-name", "OnTheMinute", headline, body])
  }

  function playCue(name) {
    if (!root.soundEnabled) return
    // Resolved against this file's own location — a bare "sounds/x.wav" is
    // relative to the shell process's cwd, not the plugin directory, and
    // silently plays nothing.
    var path = String(Qt.resolvedUrl("sounds/" + name + ".wav")).replace(/^file:\/\//, "")
    Quickshell.execDetached(["bash", "-c", "paplay " + JSON.stringify(path) + " 2>/dev/null || pw-play " + JSON.stringify(path) + " 2>/dev/null"])
  }

  // ---- Bar-widget shape contract, mirrored from panels/clock/BarWidget.qml.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  function openBigView() {
    if (root.bar && root.bar.shell && typeof root.bar.shell.summon === "function")
      root.bar.shell.summon(root.moduleName, JSON.stringify({}))
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      // Called twice: immediately so the panel has bar/settings for its
      // first paint, and once more deferred in case Panel.qml's own
      // KeyboardPanel/BorderSurface children bind before this Loader
      // finishes settling — injectPanel() is idempotent either way.
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "lobo.on-the-minute"

    function start(): void { root.start() }
    function pause(): void { root.pause() }
    function reset(): void { root.reset() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function openBigView(): void { root.openBigView() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    labelVisible: true
    hasVisualContent: true
    horizontalMargin: 8.75
    verticalPadding: 8.75

    onPressed: function(b) {
      if (b === Qt.RightButton) root.openBigView()
      else root.togglePanel()
    }
  }
}
