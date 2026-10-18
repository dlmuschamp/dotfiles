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
  onStripChanged: syncMarkers()
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

  // Update roles in place so title/viewport changes don't destroy a hovered
  // button, cancel its tooltip, or interrupt a click across refreshes.
  ListModel { id: markers }
  function syncMarkers() {
    if (!markers) return
    for (var i = 0; i < strip.windows.length; i++) {
      var w = strip.windows[i]
      var found = -1
      for (var j = i; j < markers.count; j++) {
        if (markers.get(j).address === w.address) { found = j; break }
      }
      var row = { address: w.address, windowTitle: w.title, isFocused: w.focused,
        windowVisibility: w.visibility, position: strip.start + i + 1 }
      if (found < 0) markers.insert(i, row)
      else {
        if (found !== i) markers.move(found, i, 1)
        for (var key in row) {
          if (markers.get(i)[key] !== row[key]) markers.setProperty(i, key, row[key])
        }
      }
    }
    if (markers.count > strip.windows.length)
      markers.remove(strip.windows.length, markers.count - strip.windows.length)
  }
  Component.onCompleted: { syncMarkers(); refresh() }
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      // Coalesce bursts, then reread after animations settle. The fallback
      // timer catches viewport pans and layout-rule changes without events.
      if (event && /^(activewindowv2|workspacev2|focusedmon|openwindow|closewindow|movewindowv2|changefloatingmode|fullscreen|configreloaded|monitoraddedv2|monitorremoved|activespecialv2)$/.test(event.name)) {
        debounce.restart()
        settle.restart()
      }
    }
  }
  Timer { id: debounce; interval: 70; onTriggered: root.refresh() }
  Timer { id: settle; interval: 400; onTriggered: root.refresh() }
  Timer { interval: root.positionState.scrolling ? 1500 : 5000; running: true; repeat: true; onTriggered: root.refresh() }
  Process {
    id: query
    command: ["hyprctl", "-j", "--batch", "workspaces;clients;activewindow;monitors"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var value = Model.parseSnapshot(text)
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
      model: markers
      WidgetButton {
        required property string address
        required property string windowTitle
        required property bool isFocused
        required property string windowVisibility
        required property int position
        bar: root.bar
        text: isFocused ? "●" : (windowVisibility === "visible" ? "○" : (windowVisibility === "partial" ? "◐" : "·"))
        opacity: isFocused ? 1 : (windowVisibility === "offscreen" ? 0.45 : 0.8)
        horizontalMargin: 4
        fixedHeight: root.barSize
        tooltipText: "Window " + position + "/" + root.positionState.total + ": " + windowTitle
          + "\n" + (isFocused ? "Focused" : windowVisibility) + " · Click to focus"
        onPressed: function(button) { if (button === Qt.LeftButton) root.focusAddress(address) }
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
