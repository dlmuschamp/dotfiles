import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick 6.11
import QtQuick.Effects
import QtQuick.Shapes
import qs.Commons
import qs.Ui

Item {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateHome: home + "/.local/state"
  readonly property string currentBackgroundLink: stateHome + "/omarchy/current/background"
  readonly property string modePath: stateHome + "/omarchy/current/background-mode"
  readonly property string focusPath: stateHome + "/omarchy/current/background-focus"
  readonly property string scalePath: stateHome + "/omarchy/current/background-scale"
  readonly property real minFitScale: 1.0
  readonly property real maxFitScale: 8.0

  property string currentBackground: ""
  property string displayedBackground: ""
  property string incomingBackground: ""
  property string oldBackground: ""
  property bool finishingTransition: false
  property int backgroundVersion: 0
  property int revealStartedVersion: -1
  property int pendingThemeVersion: -1
  property string pendingColorsRaw: ""
  property string pendingShellRaw: ""
  property real revealProgress: 1

  property string fillMode: "zoom"
  property real focusX: 0.5
  property real focusY: 0.5
  property real fitScale: 1.0
  property bool framing: false
  property real frameDraftX: 0.5
  property real frameDraftY: 0.5
  property real frameDraftScale: 1.0
  property string framingSavedMode: "zoom"
  property real framingSavedX: 0.5
  property real framingSavedY: 0.5
  property real framingSavedScale: 1.0

  function imageUrl(path) {
    return Util.fileUrl(path)
  }

  function normalizeMode(mode) {
    mode = String(mode || "").trim().toLowerCase()
    if (mode === "fit" || mode === "contain" || mode === "letterbox") return "fit"
    if (mode === "center" || mode === "pad") return "center"
    return "zoom"
  }

  function applyMode(mode, persist) {
    fillMode = normalizeMode(mode)
    if (persist) modeFile.setText(fillMode + "\n")
  }

  function applyFocus(x, y, persist) {
    focusX = Util.clamp(Number(x), 0, 1)
    focusY = Util.clamp(Number(y), 0, 1)
    if (persist) focusFile.setText(focusX.toFixed(4) + "," + focusY.toFixed(4) + "\n")
  }

  function applyFitScale(scale, persist) {
    var n = Number(scale)
    if (!isFinite(n) || n < minFitScale) n = minFitScale
    if (n > maxFitScale) n = maxFitScale
    fitScale = n
    if (persist) scaleFile.setText(fitScale.toFixed(4) + "\n")
  }

  function parseFocus(raw) {
    var parts = String(raw || "").trim().split(/[,\s]+/)
    if (parts.length < 2) return
    applyFocus(parts[0], parts[1], false)
  }

  function parseFitScale(raw) {
    var n = Number(String(raw || "").trim())
    if (!isFinite(n)) n = 1
    applyFitScale(n, false)
  }

  function framingCanPan() {
    return fillMode === "zoom" || (fillMode === "fit" && frameDraftScale > 1.0001)
  }

  function nudgeFitScale(delta) {
    var next = frameDraftScale * (delta > 0 ? 1.08 : 1 / 1.08)
    frameDraftScale = Util.clamp(next, minFitScale, maxFitScale)
    if (fillMode !== "fit") applyMode("fit", false)
  }

  function refreshBackground() {
    if (!readlinkProc.running) readlinkProc.running = true
  }

  function setBackground(path, instant) {
    transitionBackground("", path, path, instant, false)
  }

  function transitionBackground(fromPath, path, finalPath, instant, force) {
    path = String(path || "").trim()
    finalPath = String(finalPath || path).trim()
    fromPath = String(fromPath || "").trim()
    if (!path || (!force && finalPath === currentBackground)) return
    currentBackground = finalPath
    backgroundVersion += 1
    revealStartedVersion = -1

    revealAnimation.stop()
    finishingTransition = false

    if (instant || !displayedBackground) {
      oldBackground = ""
      incomingBackground = ""
      displayedBackground = path
      revealProgress = 1
      return
    }

    oldBackground = fromPath || displayedBackground
    incomingBackground = path
    revealProgress = 0
  }

  function setPendingTheme(colorsB64, shellB64) {
    pendingColorsRaw = Util.decodeBase64(colorsB64)
    pendingShellRaw = Util.decodeBase64(shellB64)
    pendingThemeVersion = backgroundVersion
    pendingThemeFallbackTimer.restart()
  }

  function applyPendingTheme() {
    // Background polling can advance backgroundVersion while a theme switch is
    // pending; the latest theme payload should still apply.
    if (pendingThemeVersion < 0) return
    pendingThemeFallbackTimer.stop()
    Color.loadColors(pendingColorsRaw)
    // Color.loadShell also refreshes Style so the type scale flips with the
    // background reveal instead of waiting for a separate reload path.
    Color.loadShell(pendingShellRaw)
    Style.scheduleRefresh()
    pendingThemeVersion = -1
    pendingColorsRaw = ""
    pendingShellRaw = ""
  }

  function transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64) {
    transitionBackground(fromPath, path, finalPath, false, true)
    setPendingTheme(colorsB64, shellB64)
    if (!incomingBackground || revealProgress >= 1) applyPendingTheme()
  }

  function startReveal(panel) {
    if (!incomingBackground) return
    panel.maskReady = true
    if (revealStartedVersion === backgroundVersion) return
    revealStartedVersion = backgroundVersion
    applyPendingTheme()
    revealAnimation.restart()
  }

  function openSelector() {
    if (framing) return
    if (!bgSwitchProc.running) bgSwitchProc.running = true
  }

  function openThemeSwitcher() {
    if (framing) return
    if (!themeSwitchProc.running) themeSwitchProc.running = true
  }

  function beginFrame(mode) {
    framingSavedMode = fillMode
    framingSavedX = focusX
    framingSavedY = focusY
    framingSavedScale = fitScale
    mode = String(mode || "").trim()
    if (mode) applyMode(mode, false)
    frameDraftX = focusX
    frameDraftY = focusY
    frameDraftScale = fitScale
    framing = true
  }

  function cancelFrame() {
    applyMode(framingSavedMode, false)
    applyFocus(framingSavedX, framingSavedY, false)
    applyFitScale(framingSavedScale, false)
    framing = false
  }

  function commitFrame() {
    applyFocus(frameDraftX, frameDraftY, true)
    applyFitScale(frameDraftScale, true)
    applyMode(fillMode, true)
    framing = false
  }

  Process {
    id: bgSwitchProc
    command: ["bash", "-c", "background=$(omarchy-theme-bg-switcher); [[ -n $background ]] && omarchy-theme-bg-set \"$background\""]
    onExited: root.refreshBackground()
  }

  Process {
    id: themeSwitchProc
    command: ["bash", "-c", "theme=$(omarchy-theme-switcher); [[ -n $theme ]] && omarchy-theme-set \"$theme\" >/dev/null 2>&1 &"]
    onExited: root.refreshBackground()
  }

  Process {
    id: readlinkProc
    command: ["readlink", "-f", root.currentBackgroundLink]
    stdout: StdioCollector {
      onStreamFinished: root.setBackground(String(text || "").trim(), false)
    }
  }

  FileView {
    id: modeFile
    path: root.modePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyMode(String(text() || "").trim(), false)
    onLoadFailed: root.applyMode("zoom", false)
    onFileChanged: reload()
  }

  FileView {
    id: focusFile
    path: root.focusPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.parseFocus(text())
    onLoadFailed: root.applyFocus(0.5, 0.5, false)
    onFileChanged: reload()
  }

  FileView {
    id: scaleFile
    path: root.scalePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.parseFitScale(text())
    onLoadFailed: root.applyFitScale(1, false)
    onFileChanged: reload()
  }

  IpcHandler {
    target: "background"

    function refresh(): void {
      root.refreshBackground()
    }

    function set(path: string): void {
      root.setBackground(path, false)
    }

    function setInstant(path: string): void {
      root.setBackground(path, true)
    }

    function transition(fromPath: string, path: string): void {
      root.transitionBackground(fromPath, path, path, false, false)
    }

    function themeTransition(fromPath: string, path: string, finalPath: string, colorsB64: string, shellB64: string): void {
      root.transitionBackgroundWithTheme(fromPath, path, finalPath, colorsB64, shellB64)
    }

    function setMode(mode: string): void {
      root.applyMode(mode, true)
    }

    function setFocus(x: string, y: string): void {
      root.applyFocus(x, y, true)
    }

    function setScale(scale: string): void {
      root.applyFitScale(scale, true)
    }

    function mode(): string {
      return root.fillMode
    }

    function focus(): string {
      return root.focusX.toFixed(4) + "," + root.focusY.toFixed(4)
    }

    function scale(): string {
      return root.fitScale.toFixed(4)
    }

    function frame(mode: string): void {
      root.beginFrame(mode)
    }

    function cancelFrame(): void {
      root.cancelFrame()
    }
  }

  Timer {
    id: pendingThemeFallbackTimer
    interval: 300
    repeat: false
    onTriggered: root.applyPendingTheme()
  }

  NumberAnimation {
    id: revealAnimation
    target: root
    property: "revealProgress"
    from: 0
    to: 1
    duration: 420
    easing.type: Easing.InOutCubic
    onFinished: {
      if (root.incomingBackground) {
        root.displayedBackground = root.currentBackground || root.incomingBackground
        root.finishingTransition = true
      }
      root.revealProgress = 1
    }
  }

  Component.onCompleted: {
    modeFile.reload()
    focusFile.reload()
    scaleFile.reload()
    refreshBackground()
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      visible: !remapGuard.remapping
      anchors { top: true; bottom: true; left: true; right: true }

      ScreenMoveRemap {
        id: remapGuard
        window: panel
      }
      color: "black"
      // Keep render updates enabled. The background layer has been observed to
      // lose its committed buffer while parked with updatesEnabled=false,
      // leaving a black desktop until omarchy-shell is restarted. The wallpaper
      // itself is static, so this favors correctness over a small render-loop
      // optimization.
      updatesEnabled: true

      property bool maskReady: false
      property real dragOriginX: 0
      property real dragOriginY: 0
      property real dragFocusX: 0
      property real dragFocusY: 0

      function maybeStartReveal() {
        if (!root.incomingBackground || root.revealProgress !== 0 || maskReady) return
        if (incomingFrame.status !== Image.Ready) return
        Qt.callLater(function() {
          if (!root.incomingBackground || root.revealProgress !== 0 || maskReady) return
          if (incomingFrame.status !== Image.Ready) return
          root.startReveal(panel)
        })
      }

      WlrLayershell.namespace: "omarchy-background"
      WlrLayershell.layer: root.framing ? WlrLayer.Overlay : WlrLayer.Background
      WlrLayershell.keyboardFocus: root.framing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      WallpaperImage {
        id: base
        anchors.fill: parent
        sourcePath: root.displayedBackground
        fillModeName: root.fillMode
        focusX: root.framing ? root.frameDraftX : root.focusX
        focusY: root.framing ? root.frameDraftY : root.focusY
        fitScale: root.framing ? root.frameDraftScale : root.fitScale
        imageCache: true
        onImageReady: {
          if (root.finishingTransition) {
            root.incomingBackground = ""
            root.oldBackground = ""
            root.finishingTransition = false
          }
        }
      }

      WallpaperImage {
        id: oldFrame
        anchors.fill: parent
        sourcePath: root.oldBackground
        fillModeName: root.fillMode
        focusX: root.focusX
        focusY: root.focusY
        fitScale: root.fitScale
        imageCache: false
        imageSmooth: true
        imageMipmap: true
        visible: root.oldBackground !== "" && root.revealProgress < 1 && !root.framing
        onImageReady: panel.maybeStartReveal()
      }

      Item {
        id: incomingLayer
        anchors.fill: parent
        visible: !root.framing && root.incomingBackground !== "" && incomingFrame.status === Image.Ready && (root.revealProgress >= 1 || panel.maskReady)
        layer.enabled: root.incomingBackground !== "" && root.revealProgress < 1
        layer.smooth: true
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: revealMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 0.02
        }

        WallpaperImage {
          id: incomingFrame
          anchors.fill: parent
          sourcePath: root.incomingBackground
          fillModeName: root.fillMode
          focusX: root.focusX
          focusY: root.focusY
          fitScale: root.fitScale
          imageCache: false
          imageSmooth: true
          imageMipmap: true
          onImageReady: panel.maybeStartReveal()
        }
      }

      Item {
        id: revealMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        readonly property real slant: -0.18
        readonly property real centerTop: width / 2 - slant * height / 2
        readonly property real centerBottom: width / 2 + slant * height / 2
        readonly property real reach: width / 2 + Math.abs(slant) * height / 2 + 4
        readonly property real spread: reach * root.revealProgress

        Shape {
          anchors.fill: parent
          antialiasing: true
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "white"
            strokeColor: "transparent"
            startX: revealMask.centerTop - revealMask.spread; startY: 0
            PathLine { x: revealMask.centerTop + revealMask.spread; y: 0 }
            PathLine { x: revealMask.centerBottom + revealMask.spread; y: revealMask.height }
            PathLine { x: revealMask.centerBottom - revealMask.spread; y: revealMask.height }
            PathLine { x: revealMask.centerTop - revealMask.spread; y: 0 }
          }
        }
      }

      Connections {
        target: root
        function onIncomingBackgroundChanged() {
          panel.maskReady = false
          panel.maybeStartReveal()
        }
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        visible: root.framing
        width: hintRow.width + 28
        height: hintCol.height + 20
        radius: 10
        color: Qt.rgba(0, 0, 0, 0.72)
        border.color: Qt.rgba(1, 1, 1, 0.18)
        border.width: 1

        Column {
          id: hintCol
          anchors.centerIn: parent
          spacing: 4

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: "white"
            font.pixelSize: 14
            text: root.fillMode === "fit"
              ? "Framing · fit ×" + root.frameDraftScale.toFixed(2)
              : "Framing · " + root.fillMode
          }

          Text {
            id: hintRow
            color: Qt.rgba(1, 1, 1, 0.82)
            font.pixelSize: 12
            text: root.framingCanPan()
              ? "scroll zoom · drag pan · +/- · f/z/c · Enter save · Esc cancel"
              : "scroll zoom · +/- · f/z/c · Enter save · Esc cancel"
          }
        }
      }

      MouseArea {
        id: inputLayer
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: root.framing
        focus: root.framing
        cursorShape: root.framing && root.framingCanPan() ? Qt.OpenHandCursor : Qt.ArrowCursor

        onDoubleClicked: function(mouse) {
          if (root.framing) {
            mouse.accepted = true
            return
          }
          if (mouse.button === Qt.RightButton) root.openThemeSwitcher()
          else root.openSelector()
          mouse.accepted = true
        }

        onPressed: function(mouse) {
          if (!root.framing || !root.framingCanPan() || mouse.button !== Qt.LeftButton) return
          panel.dragOriginX = mouse.x
          panel.dragOriginY = mouse.y
          panel.dragFocusX = root.frameDraftX
          panel.dragFocusY = root.frameDraftY
          cursorShape = Qt.ClosedHandCursor
        }

        onPositionChanged: function(mouse) {
          if (!root.framing || !root.framingCanPan() || !(mouse.buttons & Qt.LeftButton)) return
          var iw = Math.max(1, base.imageWidth)
          var ih = Math.max(1, base.imageHeight)
          root.frameDraftX = Util.clamp(panel.dragFocusX - (mouse.x - panel.dragOriginX) / iw, 0, 1)
          root.frameDraftY = Util.clamp(panel.dragFocusY - (mouse.y - panel.dragOriginY) / ih, 0, 1)
        }

        onReleased: function(mouse) {
          if (root.framing && root.framingCanPan()) cursorShape = Qt.OpenHandCursor
        }

        onWheel: function(wheel) {
          if (!root.framing) return
          root.nudgeFitScale(wheel.angleDelta.y)
          wheel.accepted = true
        }

        Keys.onPressed: function(event) {
          if (!root.framing) return
          if (event.key === Qt.Key_Escape) {
            root.cancelFrame()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            root.commitFrame()
            event.accepted = true
          } else if (event.key === Qt.Key_F) {
            root.applyMode("fit", false)
            event.accepted = true
          } else if (event.key === Qt.Key_Z) {
            root.applyMode("zoom", false)
            event.accepted = true
          } else if (event.key === Qt.Key_C) {
            root.applyMode("center", false)
            event.accepted = true
          } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            root.nudgeFitScale(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Minus || event.key === Qt.Key_Underscore) {
            root.nudgeFitScale(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_0) {
            root.frameDraftScale = 1
            if (root.fillMode !== "fit") root.applyMode("fit", false)
            event.accepted = true
          }
        }
      }

      Connections {
        target: root
        function onFramingChanged() {
          if (root.framing) inputLayer.forceActiveFocus()
        }
      }
    }
  }
}
