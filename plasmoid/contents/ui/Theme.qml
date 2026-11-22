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

    // Motyw „Warstwy”: kafelki stykają się jak warstwy piasku, od jasnej u góry do ciemnej na dole.
    // Card ustawia band na kolor swojej warstwy; od niego zależą tekst i akcenty tej warstwy.
    property color band: "transparent"
    readonly property bool strata: preset === "strata"
    readonly property bool banded: band.a > 0
    readonly property var strataStops: ["#f7eedf", "#efe0c6", "#e2c497", "#cfa06a", "#b5804f", "#8e5b37", "#6c412a", "#4b2c1d", "#2f1d15"]
    // Kolor warstwy w miejscu f (0 = góra, 1 = dół kolumny).
    function strataAt(f) {
        var s = strataStops, x = Math.max(0, Math.min(1, f)) * (s.length - 1), i = Math.min(s.length - 2, Math.floor(x));
        var a = Qt.lighter(s[i], 1), b = Qt.lighter(s[i + 1], 1), k = x - i;
        return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1);
    }
    // Wąski krój do liczb i tytułów w warstwach, jeśli jest w systemie; bez niego zwykła czcionka.
    readonly property string display: strata && Qt.fontFamilies().indexOf("IBM Plex Sans Condensed") >= 0 ? "IBM Plex Sans Condensed" : ""

    readonly property var presets: ({
        dune:     { base: "#211b16", ink: "#f1e7da", muted: "#bcab99", faint: "#958676", light: false },
        midnight: { base: "#141a26", ink: "#e6ecf5", muted: "#a3b1c6", faint: "#77859b", light: false },
        forest:   { base: "#16201a", ink: "#e4eee2", muted: "#a5b8a5", faint: "#7b8d7c", light: false },
        graphite: { base: "#1c1c1e", ink: "#ededed", muted: "#b0b0b3", faint: "#85858a", light: false },
        light:    { base: "#f6ecdf", ink: "#33281d", muted: "#6f5f4e", faint: "#93826f", light: true },
        paper:    { base: "#fbfbf9", ink: "#26272b", muted: "#62656d", faint: "#8b8e96", light: true },
        strata:   { base: "#8e5b37", ink: "#fff3e4", muted: "#efd6bb", faint: "#cdae90", light: false }
    })
    readonly property var cur: presets[preset] || presets.dune
    readonly property bool system: preset === "system"
    readonly property real bandL: band.hslLightness
    readonly property real bandH: Math.max(0, band.hslHue)
    readonly property bool light: banded ? bandL > 0.5 : system ? sys.window.hslLightness > 0.5 : cur.light
    // Jasna warstwa ma akcenty w odcieniu tekstu, jak ołówek na piasku; tylko glina zostaje kolorem.
    readonly property bool mono: banded && light

    readonly property color base: banded ? band : system ? sys.window : cur.base
    readonly property color ink: banded ? (light ? Qt.hsla(bandH, 0.55, 0.11, 1) : "#fff3e4") : system ? sys.windowText : cur.ink
    readonly property color muted: banded ? (light ? Qt.hsla(bandH, 0.45, bandL * 0.42, 1) : Qt.hsla(bandH, 0.55, 0.62 + bandL * 0.55, 1))
        : system ? Qt.rgba(sys.windowText.r, sys.windowText.g, sys.windowText.b, 0.72) : cur.muted
    readonly property color faint: banded ? (light ? Qt.hsla(bandH, 0.4, bandL * 0.55, 1) : Qt.hsla(bandH, 0.45, 0.5 + bandL * 0.6, 1))
        : system ? Qt.rgba(sys.windowText.r, sys.windowText.g, sys.windowText.b, 0.5) : cur.faint
    readonly property color card: banded ? band : Qt.rgba(base.r, base.g, base.b, cardOpacity)
    readonly property color edge: light ? Qt.rgba(0.2, 0.14, 0.08, 0.14) : Qt.rgba(1, 0.93, 0.84, 0.12)
    readonly property color track: banded ? Qt.rgba(ink.r, ink.g, ink.b, light ? 0.17 : 0.16)
        : light ? Qt.rgba(0.2, 0.14, 0.08, 0.12) : Qt.rgba(1, 0.92, 0.82, 0.14)
    readonly property color sky: mono ? ink : light ? "#2f7fc0" : "#6eb0e6"
    readonly property color clay: mono ? "#9a4a26" : light ? "#c8643a" : "#e58d66"
    readonly property color sage: mono ? ink : light ? "#4f8f58" : "#86bd8c"
    readonly property color dusk: mono ? ink : light ? "#7a62b8" : "#ad98da"
    readonly property color gold: mono ? ink : light ? "#a87a1e" : "#dcb15f"
    readonly property color teal: mono ? ink : light ? "#2f8a84" : "#62b5af"
    readonly property color warn: light ? "#c9761a" : "#eda24f"
    readonly property color alert: light ? "#c8443a" : "#e8695d"
    readonly property color onAccent: banded ? band : light ? "#fff8ee" : "#20180f"
    function level(p, base) { return p >= alertAt ? alert : p >= warnAt ? warn : base; }
    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }
}
