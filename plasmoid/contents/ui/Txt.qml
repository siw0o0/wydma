import QtQuick
import org.kde.plasma.plasmoid

// Tekst kafelków. Widżet bywa skalowany (skala z ustawień, dopasowanie do ekranu), a domyślny
// rendering systemowy rozstawia wtedy litery nierówno. Rendering krzywych nie ma hintingu i przy
// 12–13 px poszarpuje krawędzie liter; pole odległości w wysokiej jakości jest gładkie w każdej skali.
// Krój z ustawień, a bez niego czcionka systemu; face podmienia go dla liczb i tytułów motywu.
Text {
    readonly property var conf: Plasmoid ? Plasmoid.configuration : null
    property string face: ""
    renderType: Text.QtRendering
    renderTypeQuality: Text.HighRenderTypeQuality
    font.family: face !== "" ? face : conf && conf.fontFamily ? conf.fontFamily : Qt.application.font.family
}
