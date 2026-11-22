import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: card
    property string title
    property string note
    property color accent: theme.sky
    default property alias content: body.data
    property Theme theme: Theme {}
    // Kafelek bez danych znika z kolumny razem z odstępem.
    property bool shown: true
    // Klikalny kafelek pokazuje kursor dłoni i zgłasza tapped().
    property bool clickable: false
    // W motywie warstw nagłówka nie ma; kafelki bez własnego układu pokazują wtedy tytuł nad treścią.
    property bool leadTitle: false
    // Goły kafelek (zegar) poza warstwami: bez tła, nagłówka i marginesów.
    property bool bare: false
    readonly property bool isCard: true
    signal tapped()
    HoverHandler { enabled: card.clickable; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: card.clickable; onTapped: card.tapped() }
    width: parent ? parent.width : 330
    implicitHeight: body.implicitHeight + (layered ? padTop + 16 : bare ? 8 : 46)
    height: implicitHeight

    // Warstwy: kolor zależy od miejsca kafelka wśród widocznych kafelków kolumny
    // (rodzicem jest Loader w kolumnie układu; zegar i ukryte kafelki się nie liczą).
    readonly property bool layered: theme.strata
    readonly property var place: {
        if (!layered || !parent || !parent.parent) return [0, 1];
        var kids = parent.parent.children, k = 0, n = 0;
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i];
            if (!c.visible || !c.item || !c.item.isCard) continue;
            if (c === parent) k = n;
            n++;
        }
        return [k, Math.max(1, n)];
    }
    readonly property int bandIndex: place[0]
    readonly property bool lastBand: place[0] === place[1] - 1
    function bandColor(k) { return theme.strataAt(place[1] > 1 ? k / (place[1] - 1) : 0); }
    property Theme bandTheme: Theme {
        preset: card.theme.preset
        band: card.layered ? card.bandColor(card.bandIndex) : "transparent"
        radius: card.theme.radius
        warnAt: card.theme.warnAt
        alertAt: card.theme.alertAt
    }
    // Paleta dla treści kafelka: w warstwach własna, w pozostałych motywach wspólna.
    readonly property Theme look: layered ? bandTheme : theme

    // Fala w górnym marginesie warstwy: nad krzywą kolor warstwy wyżej, pod nią kolor tej warstwy,
    // więc krzywa nigdy nie zachodzi na treść sąsiedniego kafelka. Pierwsza warstwa nie ma fali,
    // tylko zaokrąglony wierzch, żeby stos nie wyglądał na urwany u góry.
    readonly property real wave: layered && bandIndex > 0 ? 20 : 0
    readonly property real padTop: layered ? (bandIndex > 0 ? wave + 4 : 16) : 0
    readonly property real capRadius: theme.radius + 8
    readonly property string wavePath: {
        if (!layered || width <= 0) return "";
        var w = width, h = wave, k = bandIndex, ph = k * 1.7, s = h / 26;
        var a = (6 + (k % 3) * 1.5) * s, f = Math.PI * (1.3 + (k % 2) * 0.6), d = "M0," + (h + 1);
        for (var i = 0; i <= 72; i++) {
            var x = w * i / 72;
            var y = h / 2 + a * Math.sin(x / w * f + ph) + 2.5 * s * Math.sin(x / (w * 0.088) + ph * 2);
            d += " L" + x.toFixed(1) + "," + Math.max(1, Math.min(h - 3, y)).toFixed(1);
        }
        return d + " L" + w.toFixed(1) + "," + (h + 1) + " Z";
    }
    // Zachodzi 1 px na kafelek wyżej: przy skali widżetu styk wypada na ułamku piksela i prześwituje tapeta.
    Rectangle {
        visible: card.layered && card.bandIndex > 0
        y: -1
        width: parent.width; height: card.wave + 1
        color: visible ? card.bandColor(card.bandIndex - 1) : "transparent"
    }
    Shape {
        visible: card.layered
        width: parent.width; height: card.wave + 1
        preferredRendererType: Shape.CurveRenderer
        ShapePath { strokeColor: "transparent"; fillColor: card.look.card; PathSvg { path: card.wavePath } }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        anchors.topMargin: card.wave
        visible: !card.bare || card.layered
        radius: card.layered ? 0 : theme.radius
        // Pierwsza warstwa zaokrągla wierzch, ostatnia dół całego stosu.
        topLeftRadius: card.layered ? (card.bandIndex === 0 ? card.capRadius : 0) : theme.radius
        topRightRadius: topLeftRadius
        bottomLeftRadius: card.layered ? (card.lastBand ? card.capRadius : 0) : theme.radius
        bottomRightRadius: bottomLeftRadius
        color: card.look.card
        border.color: theme.edge
        border.width: card.layered ? 0 : 1
        layer.enabled: theme.shadow && !card.layered
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowBlur: 0.7
            shadowVerticalOffset: 4
        }
    }
    RowLayout {
        id: head
        visible: !card.layered && !card.bare
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; topMargin: 12 }
        Rectangle { width: 7; height: 7; radius: 4; color: card.accent }
        Txt { text: card.title; color: theme.muted; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: theme.upperTitles ? 1.4 : 0.3; font.capitalization: theme.upperTitles ? Font.AllUppercase : Font.MixedCase; elide: Text.ElideRight; Layout.maximumWidth: card.width * 0.6 }
        Item { Layout.fillWidth: true }
        Txt { text: card.note; color: theme.faint; font.pixelSize: 11; elide: Text.ElideRight; Layout.maximumWidth: card.width * 0.55 }
    }
    ColumnLayout {
        id: body
        anchors {
            left: parent.left; right: parent.right
            top: card.layered || card.bare ? parent.top : head.bottom
            margins: card.layered ? 18 : card.bare ? 0 : 14
            topMargin: card.layered ? card.padTop : card.bare ? 0 : 8
        }
        spacing: 8
        Txt {
            visible: card.layered && card.leadTitle && card.title !== ""
            Layout.fillWidth: true
            text: card.title
            face: card.look.display
            color: card.look.ink
            font.pixelSize: 16; font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
    }
}
