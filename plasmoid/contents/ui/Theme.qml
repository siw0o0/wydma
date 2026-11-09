import QtQuick

// Paleta kafelków. Zestaw kolorów wybiera się w ustawieniach; „system” bierze tło i tekst
// z bieżącego schematu kolorów Plasmy.
QtObject {
    id: t
    property string preset: "dune"
    property real cardOpacity: 0.86
    property real radius: 18
    property bool shadow: true
    property bool upperTitles: true
    property real warnAt: 80
    property real alertAt: 95
    property SystemPalette sys: SystemPalette { colorGroup: SystemPalette.Active }

    readonly property var presets: ({
        dune:     { base: "#211b16", ink: "#f1e7da", muted: "#bcab99", faint: "#958676", light: false },
        midnight: { base: "#141a26", ink: "#e6ecf5", muted: "#a3b1c6", faint: "#77859b", light: false },
        forest:   { base: "#16201a", ink: "#e4eee2", muted: "#a5b8a5", faint: "#7b8d7c", light: false },
        graphite: { base: "#1c1c1e", ink: "#ededed", muted: "#b0b0b3", faint: "#85858a", light: false },
        light:    { base: "#f6ecdf", ink: "#33281d", muted: "#6f5f4e", faint: "#93826f", light: true },
        paper:    { base: "#fbfbf9", ink: "#26272b", muted: "#62656d", faint: "#8b8e96", light: true }
    })
    readonly property var cur: presets[preset] || presets.dune
    readonly property bool system: preset === "system"
    readonly property bool light: system ? sys.window.hslLightness > 0.5 : cur.light

    readonly property color base: system ? sys.window : cur.base
    readonly property color ink: system ? sys.windowText : cur.ink
    readonly property color muted: system ? Qt.rgba(sys.windowText.r, sys.windowText.g, sys.windowText.b, 0.72) : cur.muted
    readonly property color faint: system ? Qt.rgba(sys.windowText.r, sys.windowText.g, sys.windowText.b, 0.5) : cur.faint
    readonly property color card: Qt.rgba(base.r, base.g, base.b, cardOpacity)
    readonly property color edge: light ? Qt.rgba(0.2, 0.14, 0.08, 0.14) : Qt.rgba(1, 0.93, 0.84, 0.12)
    readonly property color track: light ? Qt.rgba(0.2, 0.14, 0.08, 0.12) : Qt.rgba(1, 0.92, 0.82, 0.14)
    readonly property color sky: light ? "#2f7fc0" : "#6eb0e6"
    readonly property color clay: light ? "#c8643a" : "#e58d66"
    readonly property color sage: light ? "#4f8f58" : "#86bd8c"
    readonly property color dusk: light ? "#7a62b8" : "#ad98da"
    readonly property color gold: light ? "#a87a1e" : "#dcb15f"
    readonly property color teal: light ? "#2f8a84" : "#62b5af"
    readonly property color warn: light ? "#c9761a" : "#eda24f"
    readonly property color alert: light ? "#c8443a" : "#e8695d"
    readonly property color onAccent: light ? "#fff8ee" : "#20180f"
    function level(p, base) { return p >= alertAt ? alert : p >= warnAt ? warn : base; }
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
}
