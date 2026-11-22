import QtQuick
import QtQuick.Shapes

// Doba jako wydma: od północy do północy, garb na dzień. Część do bieżącej chwili jest zasypana
// kolorem, a kropka nad grzbietem pokazuje teraz. Kreski u dołu to 6, 12 i 18.
Item {
    id: day
    property real progress: 0
    property color color: "#9a4a26"
    property color tick: "black"
    implicitHeight: 30

    function ridge(t) {
        var hump = t > 0.27 && t < 0.75 ? Math.pow(Math.max(0, Math.sin(Math.PI * (t - 0.27) / 0.48)), 1.3) : 0;
        return height - 3 - (height - 11) * hump - 1.5 * Math.sin(t * 20);
    }
    readonly property string path: {
        var w = width, h = height;
        if (w <= 0 || h <= 0) return "";
        var d = "M0," + h;
        for (var i = 0; i <= 96; i++) d += " L" + (w * i / 96).toFixed(1) + "," + ridge(i / 96).toFixed(1);
        return d + " L" + w.toFixed(1) + "," + h + " Z";
    }
    readonly property real p: Math.max(0, Math.min(1, progress))

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath { strokeColor: "transparent"; fillColor: Qt.rgba(day.color.r, day.color.g, day.color.b, 0.18); PathSvg { path: day.path } }
    }
    Item {
        width: parent.width * day.p
        height: parent.height
        clip: true
        Shape {
            width: day.width; height: day.height
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeColor: "transparent"; fillColor: day.color; PathSvg { path: day.path } }
        }
    }
    Repeater {
        model: [0.25, 0.5, 0.75]
        Rectangle {
            required property real modelData
            x: Math.round(day.width * modelData); y: day.height - 3
            width: 1; height: 3
            color: Qt.rgba(day.tick.r, day.tick.g, day.tick.b, 0.35)
        }
    }
    Rectangle {
        width: 7; height: 7; radius: 3.5
        color: day.color
        x: day.width * day.p - width / 2
        y: day.ridge(day.p) - height - 2
    }
}
