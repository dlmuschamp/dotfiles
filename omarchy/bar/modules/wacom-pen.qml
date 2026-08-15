import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var bar
  property string moduleName
  property var settings
  property string batteryText: ""
  property string batteryTooltip: "Wacom pen battery"

  visible: batteryText.length > 0
  implicitWidth: visible ? label.implicitWidth + 12 : 0
  implicitHeight: bar ? bar.barSize : 26

  function refresh() {
    if (!battery.running) battery.running = true
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: root.batteryText
    color: bar ? bar.foreground : "white"
    font.family: bar ? bar.fontFamily : "monospace"
    font.pixelSize: 14
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: if (bar) bar.showTooltip(parent, root.batteryTooltip)
    onExited: if (bar) bar.hideTooltip(parent)
  }

  Process {
    id: battery
    command: [Quickshell.env("HOME") + "/.config/omarchy/bar/scripts/wacom-pen-battery"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        if (!text.trim()) {
          root.batteryText = ""
          return
        }

        try {
          const status = JSON.parse(text)
          root.batteryText = String(status.text || "")
          root.batteryTooltip = String(status.tooltip || "Wacom pen battery")
        } catch (error) {
          root.batteryText = ""
        }
      }
    }
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
