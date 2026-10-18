import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "luciano.scroll-position"
  property var snapshot: []
  property bool refreshPending: false
  property string lastError: ""
  readonly property var hostWindow: root.QsWindow.window
  readonly property string screenName: hostWindow && hostWindow.screen ? hostWindow.screen.name : ""
  readonly property var positionState: Model.build(snapshot, screenName)
  readonly property var strip: Model.slice(positionState, 12)
  visible: positionState.scrolling
  implicitWidth: visible ? grid.implicitWidth : 0
  implicitHeight: visible ? grid.implicitHeight : 0

  function refresh() {
    if (query.running) { refreshPending = true; return }
    refreshPending = false
    query.running = true
  }

  function focusAddress(address) {
    var command = Model.focusCommand(address)
    if (!command) return
    Quickshell.execDetached(["hyprctl", "dispatch", command])
    settle.restart()
  }

  Component.onCompleted: refresh()
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      // Coalesce bursts, then reread after animations settle. The fallback
      // timer catches viewport pans and layout-rule changes without events.
      if (event && event.name !== "activelayout") {
        debounce.restart()
        settle.restart()
      }
    }
  }
  Timer { id: debounce; interval: 70; onTriggered: root.refresh() }
  Timer { id: settle; interval: 400; onTriggered: root.refresh() }
  Timer { interval: 1500; running: true; repeat: true; onTriggered: root.refresh() }
  Process {
    id: query
    command: ["bash", "-o", "pipefail", "-c", "hyprctl -j --batch 'workspaces;clients;activewindow;monitors' | jq -sc ."]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var value = JSON.parse(text)
          if (!Array.isArray(value) || value.length !== 4) throw new Error("Incomplete snapshot")
          root.snapshot = value
          root.lastError = ""
        } catch (error) {
          root.snapshot = []
          root.lastError = String(error)
        }
      }
    }
    onExited: function(code) {
      if (code !== 0) { root.snapshot = []; root.lastError = "hyprctl snapshot failed: " + code }
      if (root.refreshPending) debounce.restart()
    }
  }

  // Read-only runtime diagnostics, also used by the acceptance checks.
  IpcHandler {
    target: "luciano.scroll-position"
    function status(): string {
      return JSON.stringify({ screen: root.screenName, visible: root.visible,
        state: root.positionState, error: root.lastError, width: root.width, height: root.height })
    }
    function refresh(): void { root.broadcast("refresh") }
  }

  GridLayout {
    id: grid
    anchors.centerIn: parent
    columns: root.vertical ? 1 : 16
    columnSpacing: 0
    rowSpacing: 0
    WidgetButton {
      bar: root.bar
      text: "‹"
      visible: root.strip.before
      interactive: false
      horizontalMargin: 2
    }
    Repeater {
      model: root.strip.windows
      WidgetButton {
        required property var modelData
        required property int index
        bar: root.bar
        text: modelData.focused ? "●" : (modelData.visibility === "visible" ? "○" : (modelData.visibility === "partial" ? "◐" : "·"))
        opacity: modelData.focused ? 1 : (modelData.visibility === "offscreen" ? 0.45 : 0.8)
        horizontalMargin: 4
        fixedHeight: root.barSize
        tooltipText: "Window " + (root.strip.start + index + 1) + "/" + root.positionState.total + ": " + modelData.title
          + "\n" + (modelData.focused ? "Focused" : modelData.visibility) + " · Click to focus"
        onPressed: function(button) { if (button === Qt.LeftButton) root.focusAddress(modelData.address) }
      }
    }
    WidgetButton {
      bar: root.bar
      text: "›"
      visible: root.strip.after
      interactive: false
      horizontalMargin: 2
    }
    WidgetButton {
      bar: root.bar
      text: root.positionState.label
      horizontalMargin: 6
      pressable: false
      tooltipText: "Scrolling · workspace " + root.positionState.workspace
        + "\n● focused  ○ visible  ◐ partly visible  · off-screen"
        + "\nSuper+H/L: focus · Super+Backslash: toggle layout"
    }
  }
}
