import QtQuick
import QtQuick.Layouts

// Duża liczba z podpisem nad nią i szczegółem pod nią (motyw warstw), opcjonalnie z wydmą.
ColumnLayout {
    id: stat
    property string label
    property real value: 0
    property string unit: "%"
    property string detail
    property color detailColor: theme.muted
    property bool dune: false
    property color duneColor: theme.clay
    property int seed: 0
    property Theme theme: Theme {}
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.alignment: Qt.AlignTop
    spacing: 0
    Txt { text: stat.label; color: theme.ink; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; Layout.fillWidth: true }
    RowLayout {
        spacing: 2
        Txt {
            text: Math.round(stat.value)
            face: theme.display
            color: theme.level(stat.value, theme.ink)
            font.pixelSize: 42; font.weight: Font.Light; font.features: { "tnum": 1 }
            Layout.alignment: Qt.AlignBaseline
        }
        Txt { text: stat.unit; face: theme.display; color: theme.muted; font.pixelSize: 18; Layout.alignment: Qt.AlignBaseline }
    }
    Txt { visible: text !== ""; text: stat.detail; color: stat.detailColor; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
    Dune { visible: stat.dune; Layout.fillWidth: true; Layout.topMargin: 7; value: stat.value; color: theme.level(stat.value, stat.duneColor); seed: stat.seed }
}
