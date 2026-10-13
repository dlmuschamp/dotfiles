import QtQuick
import qs.Commons

// Framed wallpaper image: fit (letterbox + optional scale), zoom (cover + focus), or center.
Item {
  id: root

  property string sourcePath: ""
  property string fillModeName: "zoom"
  property real focusX: 0.5
  property real focusY: 0.5
  // Multiplier on top of fit scale (fit mode). 1 = full letterbox; >1 crops in while bars shrink.
  property real fitScale: 1.0
  property bool imageCache: true
  property bool imageSmooth: true
  property bool imageMipmap: false
  property alias status: img.status
  property alias asynchronous: img.asynchronous
  property alias sourceSize: img.sourceSize
  property real imageX: img.x
  property real imageY: img.y
  property real imageWidth: img.width
  property real imageHeight: img.height

  signal imageReady
  signal layoutChanged

  function normalizeMode(mode) {
    mode = String(mode || "").trim().toLowerCase()
    if (mode === "fit" || mode === "contain" || mode === "letterbox") return "fit"
    if (mode === "center" || mode === "pad") return "center"
    return "zoom"
  }

  function placeWithFocus(pw, ph, iw, ih, fx, fy) {
    var ix = iw <= pw ? (pw - iw) / 2 : pw / 2 - Util.clamp(fx, 0, 1) * iw
    var iy = ih <= ph ? (ph - ih) / 2 : ph / 2 - Util.clamp(fy, 0, 1) * ih
    if (iw > pw) ix = Math.min(0, Math.max(pw - iw, ix))
    if (ih > ph) iy = Math.min(0, Math.max(ph - ih, iy))
    return { x: ix, y: iy }
  }

  function canPan() {
    var mode = normalizeMode(fillModeName)
    if (mode === "zoom") return true
    if (mode === "fit") return Math.max(1, fitScale) > 1.0001
    return false
  }

  function relayout() {
    var pw = width
    var ph = height
    var sw = img.sourceSize.width
    var sh = img.sourceSize.height
    if (pw <= 0 || ph <= 0 || sw <= 0 || sh <= 0) return

    var mode = normalizeMode(fillModeName)
    var iw = 0
    var ih = 0
    var ix = 0
    var iy = 0
    var scale = 1
    var pos

    if (mode === "fit") {
      scale = Math.min(pw / sw, ph / sh) * Math.max(1, fitScale)
      iw = sw * scale
      ih = sh * scale
      pos = placeWithFocus(pw, ph, iw, ih, focusX, focusY)
      ix = pos.x
      iy = pos.y
    } else if (mode === "center") {
      iw = sw
      ih = sh
      ix = (pw - iw) / 2
      iy = (ph - ih) / 2
    } else {
      scale = Math.max(pw / sw, ph / sh)
      iw = sw * scale
      ih = sh * scale
      pos = placeWithFocus(pw, ph, iw, ih, focusX, focusY)
      ix = pos.x
      iy = pos.y
    }

    img.x = ix
    img.y = iy
    img.width = iw
    img.height = ih
    layoutChanged()
  }

  function setPan(x, y) {
    if (!canPan()) return
    var pw = width
    var ph = height
    var iw = img.width
    var ih = img.height
    if (pw <= 0 || ph <= 0 || iw <= 0 || ih <= 0) return
    if (iw > pw) img.x = Math.min(0, Math.max(pw - iw, x))
    if (ih > ph) img.y = Math.min(0, Math.max(ph - ih, y))
    if (iw > pw) focusX = Util.clamp((pw / 2 - img.x) / iw, 0, 1)
    if (ih > ph) focusY = Util.clamp((ph / 2 - img.y) / ih, 0, 1)
    layoutChanged()
  }

  Rectangle {
    anchors.fill: parent
    color: "black"
  }

  Image {
    id: img
    source: Util.fileUrl(root.sourcePath)
    asynchronous: true
    cache: root.imageCache
    smooth: root.imageSmooth
    mipmap: root.imageMipmap
    fillMode: Image.Stretch
    onStatusChanged: {
      if (status === Image.Ready) {
        root.relayout()
        root.imageReady()
      }
    }
    onSourceSizeChanged: root.relayout()
  }

  onWidthChanged: relayout()
  onHeightChanged: relayout()
  onFillModeNameChanged: relayout()
  onFocusXChanged: relayout()
  onFocusYChanged: relayout()
  onFitScaleChanged: relayout()
  onSourcePathChanged: relayout()
}
