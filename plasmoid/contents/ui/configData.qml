import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import org.kde.ksysguard.sensors as Sensors
import "tr.js" as T

// Skąd i jak często czytać czujniki, jednostki i progi kolorów.
KCM.SimpleKCM {
    id: page
    property string cfg_language
    property int cfg_interval
    property string cfg_gpu
    property alias cfg_gpuOnBattery: gpuOnBattery.checked
    property alias cfg_fahrenheit: fahrenheit.checked
    property alias cfg_netBits: netBits.checked
    property alias cfg_netGraph: netGraph.checked
    property alias cfg_netIface: netIface.text
    property alias cfg_disk: diskId.text
    property alias cfg_showSwap: showSwap.checked
    property alias cfg_showVram: showVram.checked
    property alias cfg_warnAt: warnAt.value
    property alias cfg_alertAt: alertAt.value
    property alias cfg_tempWarn: tempWarn.value
    property alias cfg_tempAlert: tempAlert.value
    property alias cfg_clickActions: clickActions.checked
    property alias cfg_procCount: procCount.value
    readonly property string lang: T.pick(cfg_language)
    function tr(text, a) { return T.tr(lang, text, a); }

    // Karty graficzne, które zna system: do listy wyboru.
    Sensors.Sensor { id: g0; sensorId: "gpu/gpu0/name" }
    Sensors.Sensor { id: g1; sensorId: "gpu/gpu1/name" }
    Sensors.Sensor { id: g2; sensorId: "gpu/gpu2/name" }
    Sensors.Sensor { id: g3; sensorId: "gpu/gpu3/name" }
    readonly property var gpus: {
        var found = [{ id: "", name: tr("Automatycznie") }];
        [g0, g1, g2, g3].forEach((s, i) => {
            if (s.status === Sensors.Sensor.Ready && s.value) found.push({ id: "gpu/gpu" + i, name: "gpu" + i + " · " + s.value });
        });
        if (cfg_gpu && !found.some(g => g.id === cfg_gpu)) found.push({ id: cfg_gpu, name: cfg_gpu });
        return found;
    }

    Kirigami.FormLayout {
        QQC2.ComboBox {
            Kirigami.FormData.label: page.tr("Odświeżanie:")
            readonly property var steps: [1, 2, 5, 10]
            model: steps.map(s => page.tr("co %1 s", s))
            currentIndex: Math.max(0, steps.indexOf(page.cfg_interval))
            onActivated: page.cfg_interval = steps[currentIndex]
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; opacity: 0.7
            text: page.tr("Rzadsze odświeżanie oszczędza baterię.")
        }
        QQC2.CheckBox { id: clickActions; Kirigami.FormData.label: page.tr("Kliknięcie:"); text: page.tr("Kafelek otwiera Monitor systemu albo ustawienia") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: page.tr("Karta graficzna") }
        QQC2.ComboBox {
            Kirigami.FormData.label: page.tr("Karta:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            model: page.gpus.map(g => g.name)
            currentIndex: Math.max(0, page.gpus.findIndex(g => g.id === page.cfg_gpu))
            onActivated: page.cfg_gpu = page.gpus[currentIndex].id
        }
        QQC2.CheckBox { id: gpuOnBattery; text: page.tr("Czytaj kartę także na baterii") }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; opacity: 0.7
            text: page.tr("Odczyt karty NVIDIA nie pozwala jej zasnąć, więc na baterii skraca czas pracy.")
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: page.tr("Pamięć i dysk") }
        QQC2.CheckBox { id: showSwap; Kirigami.FormData.label: page.tr("Wiersze:"); text: page.tr("Pamięć wymiany") }
        QQC2.CheckBox { id: showVram; text: page.tr("Pamięć karty graficznej (VRAM)") }
        QQC2.TextField { id: diskId; Kirigami.FormData.label: page.tr("Dysk:"); placeholderText: "all"; QQC2.ToolTip.text: page.tr("„all” sumuje wszystkie dyski; identyfikator pojedynczego pokazuje Monitor systemu."); QQC2.ToolTip.visible: hovered }
        QQC2.SpinBox { id: procCount; Kirigami.FormData.label: page.tr("Programów na liście:"); from: 1; to: 5 }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: page.tr("Sieć") }
        QQC2.TextField { id: netIface; Kirigami.FormData.label: page.tr("Interfejs:"); placeholderText: "all"; QQC2.ToolTip.text: page.tr("„all” sumuje wszystkie; albo nazwa, np. wlan0, enp8s0."); QQC2.ToolTip.visible: hovered }
        QQC2.CheckBox { id: netBits; Kirigami.FormData.label: page.tr("Jednostka:"); text: page.tr("Bity na sekundę (Mb/s) zamiast bajtów") }
        QQC2.CheckBox { id: netGraph; text: page.tr("Wykres ruchu") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: page.tr("Jednostki i progi") }
        QQC2.CheckBox { id: fahrenheit; Kirigami.FormData.label: page.tr("Temperatura:"); text: page.tr("Stopnie Fahrenheita") }
        RowLayout {
            Kirigami.FormData.label: page.tr("Kolor ostrzeżenia od:")
            QQC2.SpinBox { id: warnAt; from: 30; to: 99 }
            QQC2.Label { text: "%" }
            Rectangle { width: 14; height: 14; radius: 7; color: "#eda24f" }
        }
        RowLayout {
            Kirigami.FormData.label: page.tr("Kolor alarmu od:")
            QQC2.SpinBox { id: alertAt; from: 40; to: 100 }
            QQC2.Label { text: "%" }
            Rectangle { width: 14; height: 14; radius: 7; color: "#e8695d" }
        }
        RowLayout {
            Kirigami.FormData.label: page.tr("Temperatura, ostrzeżenie:")
            QQC2.SpinBox { id: tempWarn; from: 40; to: 100 }
            QQC2.Label { text: "°C" }
        }
        RowLayout {
            Kirigami.FormData.label: page.tr("Temperatura, alarm:")
            QQC2.SpinBox { id: tempAlert; from: 50; to: 110 }
            QQC2.Label { text: "°C" }
        }
    }
}
