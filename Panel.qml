import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Dropdown anchored under the bar label: edit the exercise list and minute
// count, start/pause/reset the running workout, jump to the fullscreen big
// view, and glance at recent session history. Mirrors the KeyboardPanel
// dropdown shape used by panels/clock/Panel.qml.
Panel {
  id: root
  moduleName: "lobo.on-the-minute"
  ipcTarget: "lobo.on-the-minute"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }

  // Writes exercises/minutes/soundEnabled back to shell.json, same pattern
  // as panels/clock/Panel.qml's persistSettings — applied locally first so
  // the UI updates on the same click, then pushed through the bar.
  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]

    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function saveExercises(text) {
    persistSettings({ exercisesText: text })
  }

  function saveMinutes(text) {
    persistSettings({ minutes: Model.validMinutes(text) })
  }

  function toggleSound() {
    persistSettings({ soundEnabled: !(root.hostWidget ? root.hostWidget.soundEnabled : true) })
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)
        padding: Style.spacing.panelPadding

        // ---- Live status: idle prompt, or the running countdown + current
        //      exercise while a workout is active.
        Text {
          width: parent.width
          text: root.hostWidget ? root.hostWidget.displayText : "EMOM"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
        }

        Text {
          width: parent.width
          visible: root.hostWidget ? root.hostWidget.running : false
          text: root.hostWidget ? root.hostWidget.currentExercise : ""
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
        }

        // ---- Exercise list + minute count. Freeform textarea — one
        //      exercise per line — rather than a schema-driven settings
        //      form, since the list length is arbitrary.
        Text {
          text: "EXERCISES (one per line)"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
        }

        TextArea {
          id: exercisesField
          width: parent.width
          height: Style.space(90)
          text: root.hostWidget ? root.hostWidget.exercisesText : ""
          placeholderText: "2 squats\n2 push ups\n2 kettlebell swings\n5 presses"
          onEditingFinished: root.saveExercises(text)
        }

        Row {
          width: parent.width
          spacing: Style.space(10)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "MINUTES"
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }

          TextField {
            id: minutesField
            width: Style.space(60)
            text: root.hostWidget ? String(root.hostWidget.configuredMinutes) : String(Model.DEFAULT_MINUTES)
            inputMethodHints: Qt.ImhDigitsOnly
            onEditingFinished: root.saveMinutes(text)
          }
        }

        // ---- Transport controls.
        Row {
          width: parent.width
          spacing: Style.space(8)

          PanelActionButton {
            iconText: root.hostWidget && root.hostWidget.running ? "󰏤" : "󰐊"
            tooltipText: root.hostWidget && root.hostWidget.running ? "Pause" : "Start"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: {
              if (!root.hostWidget) return
              root.hostWidget.running ? root.hostWidget.pause() : root.hostWidget.start()
            }
          }

          PanelActionButton {
            iconText: "󰑙"
            tooltipText: "Reset"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: if (root.hostWidget) root.hostWidget.reset()
          }

          PanelActionButton {
            iconText: root.hostWidget && root.hostWidget.soundEnabled ? "󰕾" : "󰝟"
            tooltipText: "Toggle sound"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.toggleSound()
          }

          PanelActionButton {
            iconText: "󰊓"
            tooltipText: "Big view"
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: if (root.hostWidget) root.hostWidget.openBigView()
          }
        }

        // ---- Recent sessions. TODO: scrollable list once history grows
        //      past a handful of entries; for now, most-recent few.
        Text {
          text: "HISTORY"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
        }

        Repeater {
          model: root.hostWidget ? root.hostWidget.history.slice(0, 5) : []

          Text {
            required property var modelData
            width: content.width
            text: modelData.finishedAt + " — " + modelData.minutes + " min, " + (modelData.exercises || []).length + " exercises"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
        }
      }
    }
  }
}
