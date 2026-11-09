import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami
import "tr.js" as T

// Dane spoza czujników: limity Claude, plan, VPN, notatka i własne polecenie.
KCM.SimpleKCM {
    id: page
    property string cfg_language
    property alias cfg_usageFile: usageFile.text
    property alias cfg_planTitle: planTitle.text
    property alias cfg_planCommand: planCommand.text
    property alias cfg_planOpen: planOpen.text
    property alias cfg_planCount: planCount.value
    property alias cfg_novpn: novpn.text
    property alias cfg_vpnWarning: vpnWarning.checked
    property alias cfg_notesTitle: notesTitle.text
    property alias cfg_notes: notes.text
    property alias cfg_customTitle: customTitle.text
    property alias cfg_customCommand: customCommand.text
    property alias cfg_customInterval: customInterval.value
    property alias cfg_showHost: showHost.checked
    readonly property string lang: T.pick(cfg_language)
    function tr(text, a) { return T.tr(lang, text, a); }
    readonly property real wide: Kirigami.Units.gridUnit * 18

    component Hint: QQC2.Label {
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24
        wrapMode: Text.WordWrap
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: page.tr("Limity Claude") }
        QQC2.TextField { id: usageFile; Kirigami.FormData.label: page.tr("Plik z limitami:"); Layout.preferredWidth: page.wide; placeholderText: "~/.cache/claudbar/usage.json" }
        Hint { text: page.tr("Plik zapisuje wtyczka Claudbar do Claude Code. Zostaw puste, jeśli jej używasz.") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: page.tr("Plan") }
        QQC2.TextField { id: planTitle; Kirigami.FormData.label: page.tr("Tytuł kafelka:"); Layout.preferredWidth: page.wide; placeholderText: page.tr("Zajęcia") }
        QQC2.TextField { id: planCommand; Kirigami.FormData.label: page.tr("Polecenie z planem:"); Layout.preferredWidth: page.wide; placeholderText: "~/.config/wydma/plan"; font.family: "monospace" }
        QQC2.TextField { id: planOpen; Kirigami.FormData.label: page.tr("Po kliknięciu uruchom:"); Layout.preferredWidth: page.wide; placeholderText: "~/.config/wydma/plan-open"; font.family: "monospace" }
        QQC2.SpinBox { id: planCount; Kirigami.FormData.label: page.tr("Kolejnych pozycji:"); from: 0; to: 6 }
        Hint { text: page.tr("Polecenie wypisuje jedną linię JSON: { zajecia: [{ przedmiot, start, koniec, sala, budynek, forma, uwaga }] }, czasy w formacie ISO. Nadaje się do zajęć, spotkań albo dyżurów.") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "VPN" }
        QQC2.TextField { id: novpn; Kirigami.FormData.label: page.tr("Wi-Fi bez VPN-a:"); Layout.preferredWidth: page.wide; placeholderText: page.tr("nazwy sieci po przecinku") }
        Hint { text: page.tr("Działa ze skryptem protonvpn-auto: w tych sieciach VPN zostaje wyłączony. Bez skryptu kafelek łączy profile VPN z NetworkManagera.") }
        QQC2.CheckBox { id: vpnWarning; Kirigami.FormData.label: page.tr("Kill switch:"); text: page.tr("Przypominaj, że jest aktywny") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: page.tr("Notatka") }
        QQC2.TextField { id: notesTitle; Kirigami.FormData.label: page.tr("Tytuł kafelka:"); Layout.preferredWidth: page.wide; placeholderText: page.tr("Notatka") }
        QQC2.TextArea { id: notes; Kirigami.FormData.label: page.tr("Treść:"); Kirigami.FormData.labelAlignment: Qt.AlignTop; Layout.preferredWidth: page.wide; Layout.preferredHeight: Kirigami.Units.gridUnit * 5; wrapMode: TextEdit.Wrap }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: page.tr("Własny kafelek") }
        QQC2.TextField { id: customTitle; Kirigami.FormData.label: page.tr("Tytuł kafelka:"); Layout.preferredWidth: page.wide; placeholderText: page.tr("Własny") }
        QQC2.TextField { id: customCommand; Kirigami.FormData.label: page.tr("Polecenie:"); Layout.preferredWidth: page.wide; placeholderText: "curl -s wttr.in/?format=3"; font.family: "monospace" }
        RowLayout {
            Kirigami.FormData.label: page.tr("Uruchamiaj co:")
            QQC2.SpinBox { id: customInterval; from: 5; to: 86400; stepSize: 5; editable: true }
            QQC2.Label { text: "s" }
        }
        Hint { text: page.tr("Kafelek pokazuje do ośmiu linii tego, co polecenie wypisze: pogodę, kurs, stan serwera, licznik zadań.") }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: page.tr("System") }
        QQC2.CheckBox { id: showHost; Kirigami.FormData.label: page.tr("Kafelek System:"); text: page.tr("Pokazuj nazwę komputera") }
    }
}
