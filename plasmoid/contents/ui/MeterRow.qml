import QtQuick
import QtQuick.Layouts

// Wiersz z nazwą, opisem, procentem i paskiem. Stały element (nie delegat), żeby
// pasek płynnie zmieniał długość zamiast rosnąć od zera przy każdym odczycie.
ColumnLayout {
    id: row
    property string name
    property string detail
    property real value: 0
    property color color
    property int nameSize: 13
    property int barHeight: 6
    property Theme theme: Theme {}
    // W warstwach jeden wiersz: nazwa, pasek, procent; szczegół odpada.
    readonly property bool compact: theme.banded
    property int nameWidth: 68
    Layout.fillWidth: true
    spacing: compact ? 0 : 4

    RowLayout {
        visible: !row.compact
        Txt { text: row.name; color: theme.ink; font.pixelSize: row.nameSize; font.weight: Font.Medium }
        Item { Layout.fillWidth: true }
        Txt { text: row.detail; color: theme.faint; font.pixelSize: 12 }
        Txt {
            text: Math.round(row.value) + "%"
            color: theme.level(row.value, theme.ink)
            font.pixelSize: row.nameSize; font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            Layout.leftMargin: 6
            Layout.minimumWidth: 34
            horizontalAlignment: Text.AlignRight
        }
    }
    Bar { Layout.fillWidth: true; visible: !row.compact; implicitHeight: row.barHeight; value: row.value; color: theme.level(row.value, row.color); track: theme.track }
    RowLayout {
        visible: row.compact
        Layout.fillWidth: true
        Layout.preferredHeight: 25
        spacing: 10
        Txt { text: row.name; color: theme.ink; font.pixelSize: 13; elide: Text.ElideRight; Layout.preferredWidth: row.nameWidth }
        Bar { Layout.fillWidth: true; implicitHeight: 7; value: row.value; color: theme.level(row.value, row.color); track: theme.track }
        Txt {
            text: Math.round(row.value) + "%"
            color: theme.level(row.value, theme.ink)
            font.pixelSize: 13; font.weight: Font.DemiBold; font.features: { "tnum": 1 }
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 38
        }
    }
}
