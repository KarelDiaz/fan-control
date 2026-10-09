import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// nbfc (NoteBook FanControl) bar widget. Clicking its bar icon opens a card
// with a 0-100 speed slider and an automatic-mode button.
// nbfc talks to its system service over a socket, so no sudo is needed:
//   nbfc status        -> fan state (target speed, auto control, temperature)
//   nbfc set -s N      -> manual speed for all fans (clears auto control)
//   nbfc set -a        -> profile-based automatic control
Item {
  id: root

  property QtObject bar: null
  property string moduleName: "karel.fan-control"
  property var settings: ({})

  property bool autoControl: true
  property int targetSpeed: 0        // highest target across fans, in %
  property real temperature: -1
  property bool statusLoaded: false
  property bool nbfcAvailable: true

  readonly property bool opened: popup.open

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() { popup.open = true }
  function close() { popup.open = false }
  function toggle() { opened ? close() : open() }

  function refreshStatus() {
    if (nbfcAvailable && !statusProc.running) statusProc.running = true
  }

  function setSpeed(percent) {
    if (!nbfcAvailable || setProc.running) return
    setProc.mode = "manual"
    setProc.speed = Math.max(0, Math.min(100, Math.round(percent)))
    targetSpeed = setProc.speed
    autoControl = false
    setProc.running = true
  }

  function setAuto() {
    if (!nbfcAvailable || setProc.running) return
    setProc.mode = "auto"
    autoControl = true
    setProc.running = true
  }

  function applyStatus(text) {
    var auto = root.autoControl
    var maxTarget = -1
    var temp = -1
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var idx = lines[i].indexOf(":")
      if (idx < 0) continue
      var key = lines[i].substring(0, idx).trim()
      var val = lines[i].substring(idx + 1).trim()
      if (key === "Auto Control Enabled") {
        auto = (val === "true")
      } else if (key === "Target Fan Speed") {
        var v = parseFloat(val)
        if (isFinite(v)) maxTarget = Math.max(maxTarget, v)
      } else if (key === "Temperature" && temp < 0) {
        var t = parseFloat(val)
        if (isFinite(t)) temp = t
      }
    }
    if (maxTarget >= 0) targetSpeed = Math.round(maxTarget)
    autoControl = auto
    temperature = temp
    statusLoaded = true
  }

  // Check once at startup that nbfc is installed.
  Process {
    id: probeProc
    command: ["sh", "-c", "command -v nbfc"]
    onExited: function(exitCode) {
      root.nbfcAvailable = (exitCode === 0)
      if (root.nbfcAvailable) root.refreshStatus()
    }
  }

  Component.onCompleted: probeProc.running = true

  Process {
    id: statusProc
    command: ["nbfc", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyStatus(text)
    }
  }

  Process {
    id: setProc
    property string mode: "auto"
    property int speed: 0
    command: mode === "auto"
      ? ["nbfc", "set", "-a"]
      : ["nbfc", "set", "-s", String(speed)]
    onExited: root.refreshStatus()
  }

  Timer {
    interval: 2000
    running: root.opened && root.nbfcAvailable
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  Timer {
    interval: 15000
    running: !root.opened && root.nbfcAvailable
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰈐"
    tooltipText: root.nbfcAvailable ? "" : "nbfc is not installed"
    active: root.nbfcAvailable && !root.autoControl
    opacity: root.nbfcAvailable ? 1.0 : 0.5
    onPressed: function(b) { root.toggle() }
  }

  // Spin the icon while the fans are driven; faster at higher speeds.
  SequentialAnimation {
    running: root.statusLoaded && root.targetSpeed > 0
    loops: Animation.Infinite
    NumberAnimation {
      target: button
      property: "textRotation"
      from: 0
      to: 360
      duration: Math.max(400, 2600 - root.targetSpeed * 20)
    }
    onRunningChanged: if (!running) button.textRotation = 0
  }

  PopupCard {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    triggerMode: "click"
    contentWidth: fittedContentWidth(Style.space(300))
    contentHeight: fittedContentHeight(panelColumn.implicitHeight, Style.space(400))

    Column {
      id: panelColumn
      width: parent ? parent.width : popup.contentWidth
      spacing: Style.space(14)

      PanelHero {
        title: "Fans"
        meta: !root.nbfcAvailable
          ? "nbfc not installed"
          : root.statusLoaded
            ? (root.autoControl ? "Automatic" : "Manual") +
              (root.temperature >= 0 ? "  ·  " + Math.round(root.temperature) + "°C" : "")
            : "Loading…"
        detail: (root.nbfcAvailable && root.statusLoaded) ? root.targetSpeed + "%" : ""
        foreground: root.bar ? root.bar.barForeground : Color.foreground
        iconComponent: fanHeroIcon
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        visible: !root.nbfcAvailable
        text: "This widget requires nbfc (NoteBook FanControl).\n\nInstall it and enable its service:\n  yay -S nbfc-linux\n  sudo systemctl enable --now nbfc_service"
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Row {
        width: parent.width
        spacing: Style.space(12)
        visible: root.nbfcAvailable

        PanelSlider {
          id: speedSlider
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - speedLabel.implicitWidth - Style.space(12)
          bar: root.bar
          minimum: 0
          maximum: 100
          step: 5
          integer: true
          value: root.targetSpeed
          onMoved: function(v) { speedLabel.text = Math.round(v) + "%" }
          onReleased: function(v) { root.setSpeed(v) }
        }

        Text {
          id: speedLabel
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: root.targetSpeed + "%"
          color: root.bar ? root.bar.barForeground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }
      }

      Button {
        width: parent.width
        visible: root.nbfcAvailable
        text: root.autoControl ? "Automatic mode enabled" : "Enable automatic mode"
        iconText: "󰔪"
        selected: root.autoControl
        enabled: !root.autoControl
        onClicked: root.setAuto()
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        visible: root.autoControl
        text: "Move the slider to set a manual speed"
        color: Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.6)
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }
  }

  Component {
    id: fanHeroIcon
    Text {
      textFormat: Text.PlainText
      text: "󰈐"
      color: root.bar ? root.bar.barForeground : Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.display
      opacity: root.autoControl ? 1.0 : 0.9
    }
  }
}
