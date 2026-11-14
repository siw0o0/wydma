import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: bar
    readonly property var conf: Plasmoid ? Plasmoid.configuration : null
    property real value: 0
    property color color: "#3d86c6"
    property color track: Qt.rgba(0.48, 0.38, 0.28, 0.13)
    implicitHeight: 8
    Rectangle { anchors.fill: parent; radius: height / 2; color: bar.track }
    Rectangle {
        height: parent.height; radius: height / 2; color: bar.color
        width: Math.max(height, parent.width * Math.max(0, Math.min(100, bar.value)) / 100)
        visible: bar.value > 0
        // Każda klatka animacji przerysowuje cały pulpit. Przy odczycie co sekundę pasek animowałby się
        // bez przerwy, a przy wyłączonych animacjach KDE (longDuration = 0) skacze od razu.
        Behavior on width {
            enabled: bar.conf ? bar.conf.interval >= 2 && Kirigami.Units.longDuration > 0 : true
            NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutCubic }
        }
    }
}
