import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

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
    signal tapped()
    HoverHandler { enabled: card.clickable; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: card.clickable; onTapped: card.tapped() }
    width: parent ? parent.width : 330
    implicitHeight: body.implicitHeight + 46
    height: implicitHeight

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: theme.radius
        color: theme.card
        border.color: theme.edge
        border.width: 1
        layer.enabled: theme.shadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowBlur: 0.7
            shadowVerticalOffset: 4
        }
    }
    RowLayout {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; topMargin: 12 }
        Rectangle { width: 7; height: 7; radius: 4; color: card.accent }
        Txt { text: card.title; color: theme.muted; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: theme.upperTitles ? 1.4 : 0.3; font.capitalization: theme.upperTitles ? Font.AllUppercase : Font.MixedCase; elide: Text.ElideRight; Layout.maximumWidth: card.width * 0.6 }
        Item { Layout.fillWidth: true }
        Txt { text: card.note; color: theme.faint; font.pixelSize: 11; elide: Text.ElideRight; Layout.maximumWidth: card.width * 0.55 }
    }
    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: head.bottom; margins: 14; topMargin: 8 }
        spacing: 8
    }
}
