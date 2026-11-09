import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import "tr.js" as T

KCM.SimpleKCM {
    id: page
    property string cfg_language
    property alias cfg_clock12: clock12.checked
    property alias cfg_seconds: seconds.checked
    property alias cfg_showDate: showDate.checked
    property string cfg_dateFormat
    property alias cfg_clockSize: size.value
    property alias cfg_darkClock: dark.checked
    readonly property string lang: T.pick(cfg_language)
    function tr(text, a) { return T.tr(lang, text, a); }
    readonly property var loc: cfg_language === "pl" ? Qt.locale("pl_PL") : cfg_language === "en" ? Qt.locale("en_GB") : Qt.locale()
    property var now: new Date()
    Timer { interval: 1000; repeat: true; running: true; onTriggered: page.now = new Date() }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: sample.implicitHeight + 32
            radius: Kirigami.Units.cornerRadius
            gradient: Gradient {
                GradientStop { position: 0; color: dark.checked ? "#dfeaf3" : "#7fb2d9" }
                GradientStop { position: 1; color: dark.checked ? "#f3e3c8" : "#c98f5a" }
            }
            Column {
                id: sample
                anchors.centerIn: parent
                spacing: -4
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(page.now, clock12.checked ? (seconds.checked ? "h:mm:ss AP" : "h:mm AP") : (seconds.checked ? "HH:mm:ss" : "HH:mm"))
                    color: dark.checked ? "#2a2018" : "white"
                    font.pixelSize: size.value; font.weight: Font.Light
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: showDate.checked
                    text: page.cfg_dateFormat === "iso" ? Qt.formatDate(page.now, "yyyy-MM-dd")
                        : page.cfg_dateFormat === "short" ? page.now.toLocaleDateString(page.loc, "ddd, d MMM")
                        : page.now.toLocaleDateString(page.loc, "dddd, d MMMM")
                    color: dark.checked ? "#2a2018" : "white"
                    font.pixelSize: Math.max(11, size.value / 4); font.weight: Font.Medium
                }
            }
        }
        Kirigami.FormLayout {
            Layout.fillWidth: true
            QQC2.CheckBox { id: clock12; Kirigami.FormData.label: page.tr("Godzina:"); text: page.tr("Zegar 12-godzinny") }
            QQC2.CheckBox { id: seconds; text: page.tr("Pokazuj sekundy") }
            RowLayout {
                Kirigami.FormData.label: page.tr("Wielkość cyfr:")
                QQC2.Slider { id: size; from: 28; to: 140; stepSize: 2; Layout.preferredWidth: Kirigami.Units.gridUnit * 12 }
                QQC2.Label { text: Math.round(size.value) + " px"; Layout.minimumWidth: Kirigami.Units.gridUnit * 2 }
            }
            QQC2.CheckBox { id: dark; Kirigami.FormData.label: page.tr("Kolor:"); text: page.tr("Ciemny tekst, na jasną tapetę") }
            Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: page.tr("Data") }
            QQC2.CheckBox { id: showDate; Kirigami.FormData.label: page.tr("Data:"); text: page.tr("Pokazuj datę pod zegarem") }
            QQC2.ComboBox {
                Kirigami.FormData.label: page.tr("Format:")
                enabled: showDate.checked
                readonly property var ids: ["long", "short", "iso"]
                model: [page.now.toLocaleDateString(page.loc, "dddd, d MMMM"), page.now.toLocaleDateString(page.loc, "ddd, d MMM"), Qt.formatDate(page.now, "yyyy-MM-dd")]
                currentIndex: Math.max(0, ids.indexOf(page.cfg_dateFormat))
                onActivated: page.cfg_dateFormat = ids[currentIndex]
            }
        }
    }
}
