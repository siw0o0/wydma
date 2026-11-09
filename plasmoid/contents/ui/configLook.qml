import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import "tr.js" as T

// Kolory, kształt kafelków i układ na ekranie, z podglądem na żywo.
KCM.SimpleKCM {
    id: page
    property string cfg_language
    property string cfg_theme
    property string cfg_fontFamily
    property alias cfg_cardOpacity: opacitySlider.value
    property alias cfg_radius: radiusSlider.value
    property alias cfg_shadow: shadow.checked
    property alias cfg_upperTitles: upper.checked
    property alias cfg_scale: scaleSlider.value
    property int cfg_columns
    property string cfg_align
    property alias cfg_spacing: spacingBox.value
    property alias cfg_fitHeight: fit.checked
    readonly property string lang: T.pick(cfg_language)
    function tr(text, a) { return T.tr(lang, text, a); }

    readonly property var themes: [
        { id: "dune", name: tr("Wydma") }, { id: "midnight", name: tr("Północ") }, { id: "forest", name: tr("Las") },
        { id: "graphite", name: tr("Grafit") }, { id: "light", name: tr("Piasek") }, { id: "paper", name: tr("Papier") },
        { id: "system", name: tr("Systemowy") }
    ]

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // Podgląd: kafelek na tle przypominającym tapetę.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: preview.implicitHeight + 36
            radius: Kirigami.Units.cornerRadius
            gradient: Gradient {
                GradientStop { position: 0; color: "#7fb2d9" }
                GradientStop { position: 0.55; color: "#e6c79a" }
                GradientStop { position: 1; color: "#c98f5a" }
            }
            Theme { id: pal; preset: page.cfg_theme; cardOpacity: opacitySlider.value / 100; radius: radiusSlider.value; shadow: shadow.checked; upperTitles: upper.checked }
            Card {
                id: preview
                theme: pal
                anchors.centerIn: parent
                width: Math.min(330, parent.width - 36)
                title: page.tr("Pamięć")
                note: page.tr("podgląd")
                accent: pal.dusk
                MeterRow { theme: pal; name: "RAM"; value: 62; detail: "9,6 / 15,4 GiB"; color: pal.dusk }
                MeterRow { theme: pal; name: page.tr("Dysk"); value: 86; detail: page.tr("wolne %1", "70 GiB"); color: pal.gold }
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Flow {
                Kirigami.FormData.label: page.tr("Kolory:")
                Kirigami.FormData.labelAlignment: Qt.AlignTop
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                Repeater {
                    model: page.themes
                    delegate: Rectangle {
                        id: tile
                        required property var modelData
                        readonly property bool current: page.cfg_theme === modelData.id
                        Theme { id: look; preset: tile.modelData.id; cardOpacity: 1 }
                        width: 84; height: 62
                        radius: 10
                        color: look.base
                        border.width: current ? 2 : 1
                        border.color: current ? Kirigami.Theme.highlightColor : Qt.rgba(0.5, 0.5, 0.5, 0.4)
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 4
                                Repeater {
                                    model: [look.sky, look.clay, look.sage, look.gold]
                                    Rectangle { required property color modelData; width: 10; height: 10; radius: 5; color: modelData }
                                }
                            }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: tile.modelData.name; color: look.ink; font.pixelSize: 11; font.weight: tile.current ? Font.DemiBold : Font.Normal }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.cfg_theme = tile.modelData.id }
                    }
                }
            }
            RowLayout {
                Kirigami.FormData.label: page.tr("Krycie kafelków:")
                QQC2.Slider { id: opacitySlider; from: 20; to: 100; stepSize: 1; Layout.preferredWidth: Kirigami.Units.gridUnit * 12 }
                QQC2.Label { text: Math.round(opacitySlider.value) + "%"; Layout.minimumWidth: Kirigami.Units.gridUnit * 2 }
            }
            RowLayout {
                Kirigami.FormData.label: page.tr("Zaokrąglenie:")
                QQC2.Slider { id: radiusSlider; from: 0; to: 28; stepSize: 1; Layout.preferredWidth: Kirigami.Units.gridUnit * 12 }
                QQC2.Label { text: Math.round(radiusSlider.value) + " px"; Layout.minimumWidth: Kirigami.Units.gridUnit * 2 }
            }
            QQC2.ComboBox {
                Kirigami.FormData.label: page.tr("Czcionka:")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
                readonly property var families: [""].concat(Qt.fontFamilies())
                model: [page.tr("Systemowa")].concat(Qt.fontFamilies())
                currentIndex: Math.max(0, families.indexOf(page.cfg_fontFamily))
                onActivated: page.cfg_fontFamily = families[currentIndex]
            }
            QQC2.CheckBox { id: shadow; Kirigami.FormData.label: page.tr("Kafelki:"); text: page.tr("Cień pod kafelkami") }
            QQC2.CheckBox { id: upper; text: page.tr("Tytuły wersalikami") }

            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: page.tr("Układ na ekranie") }
            RowLayout {
                Kirigami.FormData.label: page.tr("Skala:")
                QQC2.Slider { id: scaleSlider; from: 50; to: 200; stepSize: 5; Layout.preferredWidth: Kirigami.Units.gridUnit * 12 }
                QQC2.Label { text: Math.round(scaleSlider.value) + "%"; Layout.minimumWidth: Kirigami.Units.gridUnit * 2 }
            }
            QQC2.ComboBox {
                Kirigami.FormData.label: page.tr("Kolumny:")
                model: [page.tr("Automatycznie, według miejsca"), "1", "2", "3", "4"]
                currentIndex: Math.max(0, Math.min(4, page.cfg_columns))
                onActivated: page.cfg_columns = currentIndex
            }
            QQC2.ComboBox {
                Kirigami.FormData.label: page.tr("Dosuwanie:")
                model: [page.tr("Do prawej krawędzi"), page.tr("Do lewej krawędzi")]
                currentIndex: page.cfg_align === "left" ? 1 : 0
                onActivated: page.cfg_align = currentIndex === 1 ? "left" : "right"
            }
            QQC2.SpinBox { id: spacingBox; Kirigami.FormData.label: page.tr("Odstęp między kafelkami:"); from: 0; to: 40 }
            QQC2.CheckBox { id: fit; Kirigami.FormData.label: page.tr("Mały ekran:"); text: page.tr("Zmniejsz całość, gdy nie mieści się na wysokość") }
            QQC2.Label {
                Layout.fillWidth: true
                Layout.maximumWidth: Kirigami.Units.gridUnit * 22
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                text: page.tr("Szerokość i położenie ustawia się na pulpicie w trybie edycji. Przy kolumnach automatycznych widżet sam rozkłada kafelki obok siebie tak, żeby zmieściły się w swoim obszarze.")
            }

            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: page.tr("Język") }
            QQC2.ComboBox {
                Kirigami.FormData.label: page.tr("Język:")
                readonly property var ids: ["auto", "pl", "en"]
                model: [page.tr("Według systemu"), "Polski", "English"]
                currentIndex: Math.max(0, ids.indexOf(page.cfg_language))
                onActivated: page.cfg_language = ids[currentIndex]
            }
        }
    }
}
