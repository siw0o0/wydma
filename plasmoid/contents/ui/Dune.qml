import QtQuick
import QtQuick.Shapes

// Pasek w kształcie wydmy: sylwetka zasypana kolorem do poziomu procentu.
Item {
    id: dune
    property real value: 0
    property color color: "#9a4a26"
    property int seed: 0
    implicitHeight: 22
    readonly property string path: {
        var w = width, h = height;
        if (w <= 0 || h <= 0) return "";
        var d = "M0," + h;
        for (var i = 0; i <= 60; i++) {
            var t = i / 60, x = w * t;
            var y = h - 3 - (h - 7) * Math.pow(Math.sin(Math.PI * Math.min(1, t * 1.05)), 1.6) * (0.75 + 0.25 * Math.sin(t * 9 + dune.seed));
            d += " L" + x.toFixed(1) + "," + y.toFixed(1);
        }
        return d + " L" + w.toFixed(1) + "," + h + " Z";
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath { strokeColor: "transparent"; fillColor: Qt.rgba(dune.color.r, dune.color.g, dune.color.b, 0.22); PathSvg { path: dune.path } }
    }
    Item {
        width: parent.width * Math.max(0, Math.min(100, dune.value)) / 100
        height: parent.height
        clip: true
        Shape {
            width: dune.width; height: dune.height
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: "transparent"; fillColor: dune.color; PathSvg { path: dune.path } }
        }
    }
}
