import QtQuick
import org.kde.plasma.plasmoid

// Tekst kafelków. Widżet bywa skalowany (skala z ustawień, dopasowanie do ekranu), a domyślny
// rendering systemowy rozstawia wtedy litery nierówno; rendering krzywych jest ostry w każdej skali.
// Krój z ustawień, a bez niego czcionka systemu.
Text {
    readonly property var conf: Plasmoid ? Plasmoid.configuration : null
    renderType: Text.CurveRendering
    font.family: conf && conf.fontFamily ? conf.fontFamily : Qt.application.font.family
}
