import QtQuick
import org.kde.plasma.configuration
import "../ui/tr.js" as T

ConfigModel {
    readonly property string lang: T.pick("auto")
    ConfigCategory {
        name: T.tr(lang, "Kafelki")
        icon: "view-list-details"
        source: "configCards.qml"
    }
    ConfigCategory {
        name: T.tr(lang, "Wygląd")
        icon: "preferences-desktop-theme-global"
        source: "configLook.qml"
    }
    ConfigCategory {
        name: T.tr(lang, "Zegar")
        icon: "preferences-system-time"
        source: "configClock.qml"
    }
    ConfigCategory {
        name: T.tr(lang, "Czujniki")
        icon: "utilities-system-monitor"
        source: "configData.qml"
    }
    ConfigCategory {
        name: T.tr(lang, "Źródła")
        icon: "preferences-system-network"
        source: "configSources.qml"
    }
}
