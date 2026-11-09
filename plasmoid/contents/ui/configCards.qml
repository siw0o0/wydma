import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import "tr.js" as T

// Które kafelki widać i w jakiej kolejności. Włączone stoją na górze w kolejności wyświetlania.
KCM.SimpleKCM {
    id: page
    property string cfg_cards
    property string cfg_language
    readonly property string lang: T.pick(cfg_language)
    function tr(text, a) { return T.tr(lang, text, a); }

    readonly property var all: [
        { id: "clock", icon: "clock", name: tr("Zegar"), hint: tr("godzina i data, bez tła") },
        { id: "plan", icon: "view-calendar-day", name: tr("Plan"), hint: tr("najbliższe zajęcia albo spotkania z własnego polecenia") },
        { id: "claude", icon: "dialog-messages", name: tr("Limity Claude"), hint: tr("zużycie limitu 5 h i tygodniowego") },
        { id: "cpu", icon: "cpu", name: tr("Procesor i grafika"), hint: tr("obciążenie i temperatura") },
        { id: "memory", icon: "memory", name: tr("Pamięć"), hint: tr("RAM, wymiana, VRAM i dysk") },
        { id: "network", icon: "network-wired", name: tr("Sieć"), hint: tr("pobieranie i wysyłanie z wykresem") },
        { id: "power", icon: "battery", name: tr("Zasilanie"), hint: tr("bateria, profil, tryb ładowania, słuchawki") },
        { id: "gpumode", icon: "video-display", name: tr("Tryb grafiki"), hint: tr("Hybrid, iGPU, dGPU na laptopach Legion") },
        { id: "vpn", icon: "network-vpn", name: "VPN", hint: tr("stan, przełącznik i lista profili") },
        { id: "system", icon: "computer", name: tr("System"), hint: tr("dystrybucja, jądro, Plasma, czas działania") },
        { id: "procs", icon: "view-process-system", name: tr("Najwięcej pamięci"), hint: tr("programy zajmujące najwięcej RAM-u") },
        { id: "notes", icon: "note", name: tr("Notatka"), hint: tr("własny tekst na pulpicie") },
        { id: "custom", icon: "utilities-terminal", name: tr("Własny"), hint: tr("wynik dowolnego polecenia") }
    ]
    readonly property var active: cfg_cards.split(",").map(c => c.trim()).filter((c, i, list) => all.some(a => a.id === c) && list.indexOf(c) === i)
    readonly property var rows: active.map(id => all.find(a => a.id === id)).concat(all.filter(a => active.indexOf(a.id) < 0))
    function toggle(id, on) {
        var list = active.filter(c => c !== id);
        if (on) list.push(id);
        cfg_cards = list.join(",");
    }
    function move(id, by) {
        var list = active.slice(), from = list.indexOf(id), to = from + by;
        if (from < 0 || to < 0 || to >= list.length) return;
        list.splice(to, 0, list.splice(from, 1)[0]);
        cfg_cards = list.join(",");
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing
        QQC2.Label {
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            wrapMode: Text.WordWrap
            opacity: 0.7
            text: page.tr("Zaznacz kafelki, które mają być widoczne, i ustaw ich kolejność strzałkami. Kafelek bez danych (np. VPN bez profili) chowa się sam.")
        }
        Repeater {
            model: page.rows.length
            delegate: Rectangle {
                id: row
                required property int index
                readonly property var item: page.rows[index]
                readonly property int place: page.active.indexOf(item.id)
                readonly property bool on: place >= 0
                Layout.fillWidth: true
                implicitHeight: line.implicitHeight + Kirigami.Units.smallSpacing * 2
                radius: Kirigami.Units.cornerRadius
                color: on ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.10) : "transparent"
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, on ? 0.18 : 0.08)
                RowLayout {
                    id: line
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: Kirigami.Units.largeSpacing; rightMargin: Kirigami.Units.smallSpacing }
                    spacing: Kirigami.Units.largeSpacing
                    QQC2.CheckBox { checked: row.on; onToggled: page.toggle(row.item.id, checked) }
                    Kirigami.Icon { source: row.item.icon; implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: implicitWidth; opacity: row.on ? 1 : 0.5 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        opacity: row.on ? 1 : 0.6
                        QQC2.Label { text: row.item.name; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                        QQC2.Label { text: row.item.hint; font: Kirigami.Theme.smallFont; opacity: 0.7; Layout.fillWidth: true; elide: Text.ElideRight }
                    }
                    QQC2.Label { visible: row.on; text: (row.place + 1); opacity: 0.5; font: Kirigami.Theme.smallFont }
                    QQC2.ToolButton { icon.name: "arrow-up"; enabled: row.on && row.place > 0; onClicked: page.move(row.item.id, -1); QQC2.ToolTip.text: page.tr("Wyżej"); QQC2.ToolTip.visible: hovered }
                    QQC2.ToolButton { icon.name: "arrow-down"; enabled: row.on && row.place < page.active.length - 1; onClicked: page.move(row.item.id, 1); QQC2.ToolTip.text: page.tr("Niżej"); QQC2.ToolTip.visible: hovered }
                }
            }
        }
        RowLayout {
            Layout.topMargin: Kirigami.Units.smallSpacing
            QQC2.Button { icon.name: "edit-select-all"; text: page.tr("Włącz wszystkie"); onClicked: page.cfg_cards = page.active.concat(page.all.map(a => a.id).filter(id => page.active.indexOf(id) < 0)).join(",") }
            QQC2.Button { icon.name: "edit-reset"; text: page.tr("Przywróć domyślne"); onClicked: page.cfg_cards = "clock,plan,claude,cpu,memory,network,power,gpumode,vpn" }
        }
    }
}
