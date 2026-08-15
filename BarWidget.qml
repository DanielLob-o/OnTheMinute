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
BarWidget {
  id: root
  moduleName: "lobo.on-the-minute"

  // ---- Configuration. Persisted inline in shell.json (see Panel.qml's
  //      persistSettings), same pattern the clock widget uses for its
  //      birthYear/lifeExpectancy fields.
  readonly property string exercisesText: setting("exercisesText", "")
  readonly property var exercises: Model.parseExercises(exercisesText)
  readonly property int configuredMinutes: Model.validMinutes(setting("minutes", Model.DEFAULT_MINUTES))
  readonly property bool soundEnabled: setting("soundEnabled", true) !== false

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

  function recordSession() {
    root.history = History.addSession(root.history, {
      finishedAt: new Date().toISOString(),
      minutes: root.configuredMinutes,
      exercises: root.exercises,
      roundsCompleted: root.minuteIndex
    }, root.historyLimit)
    saveHistory()
  }

  // ---- Live countdown state. Transient — a restart of the shell should not
  //      try to resume mid-workout.
  property bool running: false
  property bool paused: false
  property int minuteIndex: 0       // whole minutes elapsed since start
  property int secondsLeft: 59      // counts down within the current minute
  readonly property string currentExercise: Model.exerciseForMinute(root.exercises, root.minuteIndex)
  readonly property string displayText: root.running
    ? Model.formatClock(root.configuredMinutes - root.minuteIndex - 1, root.secondsLeft)
    : "EMOM"

  function start() {
    if (!Model.canStart(root.exercises, root.configuredMinutes)) return
    root.running = true
    root.paused = false
    root.minuteIndex = 0
    root.secondsLeft = 59
    notify("EMOM started", root.currentExercise)
    playCue("go")
  }

  function pause() {
    if (!root.running) return
    root.paused = !root.paused
  }

  function reset() {
    root.running = false
    root.paused = false
    root.minuteIndex = 0
    root.secondsLeft = 59
  }

  function tick() {
    if (!root.running || root.paused) return

    if (Model.isWarningPhase(root.secondsLeft)) {
      // TODO: fire once per second for the last 5 seconds, not just at the
      // boundary — a short distinct "tick" cue per the design doc in
      // sounds/README.md.
      playCue("warning")
    }

    if (root.secondsLeft <= 0) {
      root.minuteIndex += 1
      if (root.minuteIndex >= root.configuredMinutes) {
        root.running = false
        recordSession()
        notify("EMOM complete", root.configuredMinutes + " minute" + (root.configuredMinutes === 1 ? "" : "s") + " done")
        playCue("done")
        return
      }
      root.secondsLeft = 59
      notify("Minute " + (root.minuteIndex + 1), root.currentExercise)
      playCue("minute")
      return
    }

    root.secondsLeft -= 1
  }

  Timer {
    interval: 1000
    running: root.running
    repeat: true
    onTriggered: root.tick()
  }

  // ---- Notifications + sound. Desktop toast for visibility when the bar
  //      isn't in view, bundled audio cues (see sounds/README.md) played
  //      independently via paplay so each event gets a distinct, reliable
  //      sound regardless of the system notification theme.
  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  function notify(headline, body) {
    Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-notification-send", "--app-name", "OnTheMinute", headline, body])
  }

  function playCue(name) {
    if (!root.soundEnabled) return
    // TODO: resolve the plugin's own directory rather than assuming CWD;
    // fall back from paplay to pw-play if paplay is unavailable.
    Quickshell.execDetached(["paplay", "sounds/" + name + ".wav"])
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
