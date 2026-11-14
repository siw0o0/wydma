import QtQuick

Canvas {
    id: ring
    property real value: 0
    property color color: "#3d86c6"
    property color track: Qt.rgba(0.48, 0.38, 0.28, 0.13)
    property real thickness: 9
    implicitWidth: 104; implicitHeight: 104
    // Rysuje od nowa tylko, gdy zmienił się pełny procent albo kolor; drobne wahania odczytu nie budzą grafiki.
    property int drawn: -1
    onValueChanged: if (Math.round(value) !== drawn) requestPaint()
    onColorChanged: requestPaint()
    onPaint: {
        drawn = Math.round(value);
        var c = getContext("2d"), r = Math.min(width, height) / 2 - thickness / 2, s = 0.75 * Math.PI, sweep = 1.5 * Math.PI;
        c.reset(); c.lineCap = "round"; c.lineWidth = thickness;
        c.strokeStyle = track; c.beginPath(); c.arc(width / 2, height / 2, r, s, s + sweep); c.stroke();
        var v = Math.max(0, Math.min(100, value)) / 100;
        if (v > 0) { c.strokeStyle = color; c.beginPath(); c.arc(width / 2, height / 2, r, s, s + sweep * v); c.stroke(); }
    }
}
