import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui

// Fullscreen "big screen" workout view — for running the timer somewhere
// visible across the room instead of squinting at the bar. Summoned via
// BarWidget.qml's openBigView() (shell.summon) or directly by IPC/keybind.
//
// This is a separately-summoned top-level plugin surface with no direct
// reference to the BarWidget instance that owns the countdown, so it reads
// live state from a small file BarWidget.qml writes on every tick, watched
// here for changes — the same "write, watch, react" shape the built-in
// image picker uses for its selection round-trip. (A shared service
// singleton would be the more direct route, but Quickshell's synchronous
// third-party service loader reliably fails on this shell with a spurious
// "File name case mismatch", reproduced even outside a symlinked plugin
// directory.)
//
// Structure otherwise mirrors shell/plugins/reminders/ReminderFlow.qml's
// overlay (PanelWindow + WlrLayershell), swapping the input flow for a
// read-out.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string liveStatePath: Quickshell.env("HOME") + "/.local/state/omarchy/on-the-minute-live.json"
  property bool running: false
  property string displayText: "EMOM"
  property string exercisesLabel: ""
  property var exercises: []

  FileView {
    id: liveStateFile
    path: root.liveStatePath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.applyLiveState(text())
    onLoadFailed: root.applyLiveState("")
  }

  function applyLiveState(raw) {
    var state = {}
    try { state = JSON.parse(raw || "{}") } catch (e) { state = {} }
    root.running = state.running === true
    root.displayText = state.displayText || "EMOM"
    root.exercisesLabel = state.exercisesLabel || ""
    root.exercises = Array.isArray(state.exercises) ? state.exercises : []
  }

  function open(payloadJson) {
    root.opened = true
    liveStateFile.reload()
  }

  function close() {
    root.opened = false
  }

  function toggle() {
    root.opened ? root.close() : root.open("{}")
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: Color.background
    WlrLayershell.namespace: "on-the-minute-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true

      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.close()
          event.accepted = true
        }
      }

      Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - Style.space(80), Style.space(900))
        spacing: Style.space(24)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.displayText
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: 160
          font.bold: true
        }

        Column {
          width: parent.width
          visible: root.running && root.exercises.length > 0
          spacing: Style.space(8)

          Repeater {
            model: root.exercises

            Text {
              required property string modelData
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              text: modelData
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.title
            }
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: !root.running
          text: "Esc to close · configure from the bar widget"
          color: Qt.darker(Color.foreground, 1.5)
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}
