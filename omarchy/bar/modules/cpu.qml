import QtQuick

Item {
  property var bar
  property string moduleName
  property var settings

  implicitWidth: 28
  implicitHeight: bar ? bar.barSize : 26

  Text {
    anchors.centerIn: parent
    text: "󰍛"
    color: bar ? bar.foreground : "white"
    font.family: bar ? bar.fontFamily : "monospace"
    font.pixelSize: 16
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onEntered: if (bar) bar.showTooltip(parent, "System monitor")
    onExited: if (bar) bar.hideTooltip(parent)
    onClicked: if (bar) bar.run("uwsm-app -- xdg-terminal-exec btop")
  }
}
