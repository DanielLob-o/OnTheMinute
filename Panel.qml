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
  property int expandedHistoryIndex: -1

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  // Explicit refresh point for the two editable fields instead of a live
  // `text:` binding — see the comment on exercisesField. Runs whenever the
  // panel opens (so edits made elsewhere, e.g. reset, aren't stale) and
  // once hostWidget first arrives.
  function syncFields() {
    if (!root.hostWidget) return
    exercisesField.text = root.hostWidget.exercisesText
    minutesField.text = String(root.hostWidget.configuredMinutes)
  }

  onHostWidgetChanged: syncFields()

  function open() { root.controller.show(); syncFields() }
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

  // Loads a past session's exercises and minutes back into the current
  // config, same fields the dropdown edits, so repeating a workout is just
  // clicking history instead of retyping it.
  function repeatSession(session) {
    if (!session) return
    persistSettings({
      exercisesText: Model.exercisesToText(session.exercises || []),
      minutes: Model.validMinutes(session.minutes)
    })
    syncFields()
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
    contentHeight: panel.fittedContentHeight(content.implicitHeight + Style.spacing.panelPadding * 2)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.spacing.panelPadding
        spacing: Style.space(10)

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
          // The full list is the round for every minute — an EMOM repeats
          // the same exercises each time rather than rotating through them.
          visible: root.hostWidget ? root.hostWidget.running : false
          text: root.hostWidget ? root.hostWidget.exercisesLabel : ""
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
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

        // No themed multi-line control ships in qs.Ui (only a single-line
        // TextField), so this mirrors that component's own styling —
        // BorderSurface background, focus/hover borderSpec, same palette —
        // by hand rather than falling through to the unstyled stock
        // QtQuick.Controls.TextArea look.
        TextArea {
          id: exercisesField
          width: parent.width
          height: Style.space(90)
          // Not a live `text:` binding — TextArea/TextField break their own
          // binding the moment `text` is set (needed so users can type),
          // so this only ever ran once at creation. If hostWidget's real
          // settings weren't hydrated yet at that instant, the field got
          // permanently stuck on the placeholder-empty default and any
          // later blur would silently overwrite the saved value with it.
          // Synced explicitly instead — see syncFields().
          placeholderText: "2 squats\n2 push ups\n2 kettlebell swings\n5 presses"
          wrapMode: TextArea.NoWrap

          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          selectionColor: Style.selectionFillFor(root.contentForeground, Color.accent)
          selectedTextColor: root.contentForeground
          placeholderTextColor: Qt.darker(root.contentForeground, 1.6)

          readonly property bool _focused: activeFocus
          readonly property var _borderSpec: Border.controlSpec(_focused ? "focus" : (hovered ? "hover-cursor" : "normal"), root.contentForeground, Color.accent)

          leftPadding: Style.spacing.controlPaddingX + Border.left(_borderSpec)
          rightPadding: Style.spacing.controlPaddingX + Border.right(_borderSpec)
          topPadding: Style.spacing.inputPaddingY + Border.top(_borderSpec)
          bottomPadding: Style.spacing.inputPaddingY + Border.bottom(_borderSpec)

          background: BorderSurface {
            color: Style.controlFill(exercisesField._focused, exercisesField.hovered, root.contentForeground, Color.accent)
            borderSpec: exercisesField._borderSpec
            radius: Style.cornerRadius
          }

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

        // ---- Session history: capped-height scrollable list rather than
        //      truncating to a handful of rows, so nothing is unreachable
        //      once it piles up. Click a row to expand the exercises done
        //      in that session; the trash icon discards it.
        Text {
          text: "HISTORY"
          color: Qt.darker(root.contentForeground, 1.5)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.letterSpacing: 1
        }

        Text {
          visible: !root.hostWidget || root.hostWidget.history.length === 0
          text: "No sessions yet"
          color: Qt.darker(root.contentForeground, 1.6)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
        }

        ListView {
          id: historyList
          visible: root.hostWidget && root.hostWidget.history.length > 0
          width: content.width
          height: Math.min(Style.space(180), contentHeight)
          clip: true
          spacing: Style.space(6)
          boundsBehavior: Flickable.StopAtBounds
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
          model: root.hostWidget ? root.hostWidget.history : []

          delegate: Column {
            id: historyRow
            required property var modelData
            required property int index
            width: historyList.width
            spacing: Style.space(4)

            Row {
              width: parent.width
              spacing: Style.space(8)

              Item {
                width: parent.width - repeatButton.width - deleteButton.width - parent.spacing * 2
                height: summaryText.implicitHeight

                Text {
                  id: summaryText
                  anchors.fill: parent
                  text: Model.formatSessionDate(historyRow.modelData.finishedAt) + " · " + historyRow.modelData.minutes + " min, " + (historyRow.modelData.exercises || []).length + " exercises"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.expandedHistoryIndex = (root.expandedHistoryIndex === historyRow.index ? -1 : historyRow.index)
                }
              }

              PanelActionButton {
                id: repeatButton
                iconText: "↻"
                tooltipText: "Repeat this session"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.repeatSession(historyRow.modelData)
              }

              PanelActionButton {
                id: deleteButton
                iconText: "󰆴"
                tooltipText: "Delete"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: {
                  if (root.expandedHistoryIndex === historyRow.index) root.expandedHistoryIndex = -1
                  if (root.hostWidget) root.hostWidget.deleteHistoryEntry(historyRow.index)
                }
              }
            }

            Text {
              width: parent.width
              visible: root.expandedHistoryIndex === historyRow.index
              text: (historyRow.modelData.exercises || []).join("\n")
              color: Qt.darker(root.contentForeground, 1.2)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }
  }
}
