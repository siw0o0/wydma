import QtQuick
import QtQuick.Shapes

// Ikona liniowa 24×24 w kolorze tekstu. Ikony Breeze mają własne kolory, które nie pasują do warstw.
Item {
    id: icon
    property string name
    property color color: "black"
    property real size: 20
    implicitWidth: size
    implicitHeight: size
    readonly property var paths: ({
        plug: "M9 3v5M15 3v5M6.5 8h11v3a5.5 5.5 0 0 1-11 0zM12 16.5V21",
        battery: "M4.5 7h12A1.5 1.5 0 0 1 18 8.5v7a1.5 1.5 0 0 1-1.5 1.5h-12A1.5 1.5 0 0 1 3 15.5v-7A1.5 1.5 0 0 1 4.5 7zM21 10.5v3",
        shield: "M12 3l8 3v6c0 4.6-3.4 8.2-8 9-4.6-.8-8-4.4-8-9V6zM8.5 12l2.5 2.5 4.5-5",
        shieldOff: "M12 3l8 3v6c0 4.6-3.4 8.2-8 9-4.6-.8-8-4.4-8-9V6zM9.5 9.5l5 5M14.5 9.5l-5 5",
        headset: "M4 15v-3a8 8 0 0 1 16 0v3M4 15a2 2 0 0 1 2-2h1v6H6a2 2 0 0 1-2-2zM20 15a2 2 0 0 0-2-2h-1v6h1a2 2 0 0 0 2-2z",
        refresh: "M20 12a8 8 0 1 1-2.6-5.9M20 4v5h-5"
    })
    Shape {
        width: 24; height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: icon.color; strokeWidth: 1.7; fillColor: "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.paths[icon.name] || "" }
        }
    }
}
