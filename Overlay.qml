import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// Fullscreen "big screen" workout view — for running the timer somewhere
// visible across the room instead of squinting at the bar. Summoned via
// BarWidget.qml's openBigView() (shell.summon) or directly by IPC/keybind.
// Structure mirrors shell/plugins/reminders/ReminderFlow.qml's overlay
// (PanelWindow + WlrLayershell), swapping the input flow for a read-out.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false

  // The bar widget instance owns timer state; the overlay just displays it.
  // TODO: resolve the live BarWidget instance instead of tracking a copy —
  // likely via a shared Service singleton once one exists, so the overlay
  // doesn't drift from the bar's own countdown between summons.
  property string displayText: "EMOM"
  property string currentExercise: ""
  property bool running: false

  function open(payloadJson) {
    root.opened = true
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
        spacing: Style.space(24)

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: root.displayText
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: 160
          font.bold: true
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          visible: root.running
          text: root.currentExercise
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.title
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
