import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.ksysguard.sensors as Sensors
import "tr.js" as T

PlasmoidItem {
    id: root
    readonly property var cfg: Plasmoid.configuration
    // Teksty w kodzie są po polsku; tr() podaje je w wybranym języku.
    readonly property string lang: T.pick(cfg.language)
    function tr(text, a, b) { return T.tr(lang, text, a, b); }
    readonly property var loc: cfg.language === "pl" ? Qt.locale("pl_PL") : cfg.language === "en" ? Qt.locale("en_GB") : Qt.locale()
    property var now: new Date()
    property var status: ({})
    property var down: []
    property var up: []

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // Skrót z menu programów zapisuje nową wartość openSettings, a widżet otwiera wtedy swoje ustawienia.
    property bool ready: false
    Component.onCompleted: ready = true
    readonly property string openSettings: cfg.openSettings
    onOpenSettingsChanged: if (ready && openSettings !== "") Plasmoid.internalAction("configure").trigger()
    preferredRepresentation: fullRepresentation

    Theme {
        id: pal
        preset: root.cfg.theme
        cardOpacity: root.cfg.cardOpacity / 100
        radius: root.cfg.radius
        shadow: root.cfg.shadow
        upperTitles: root.cfg.upperTitles
        warnAt: root.cfg.warnAt
        alertAt: Math.max(root.cfg.alertAt, root.cfg.warnAt)
    }

    // Włączone kafelki w kolejności z ustawień.
    readonly property var known: ["clock", "plan", "claude", "cpu", "memory", "network", "power", "gpumode", "vpn", "system", "procs", "notes", "custom"]
    readonly property var cards: String(cfg.cards).split(",").map(c => c.trim()).filter((c, i, all) => known.indexOf(c) >= 0 && all.indexOf(c) === i)
    function has(card) { return cards.indexOf(card) >= 0; }

    function ok(s) { return s.status === Sensors.Sensor.Ready && s.value !== undefined && Number.isFinite(Number(s.value)); }
    // Ostatni poprawny odczyt na czujnik: chwilowy brak danych nie zrzuca paska do zera.
    property var last: ({})
    function num(s) {
        if (ok(s)) last[s.sensorId] = Number(s.value);
        return last[s.sensorId] || 0;
    }
    function txt(s) { return s.status === Sensors.Sensor.Ready && s.formattedValue ? s.formattedValue : "—"; }
    function pct(v) { return Math.round(v) + "%"; }
    function dec(v, digits) { return Number(v).toLocaleString(loc, "f", digits); }
    function gib(bytes) { return dec(bytes / 1073741824, 1); }
    function size(bytes) { return bytes >= 1073741824 ? gib(bytes) + " GiB" : Math.round(bytes / 1048576) + " MiB"; }
    function temp(s) {
        if (!ok(s)) return "—";
        var v = Number(s.value);
        return cfg.fahrenheit ? Math.round(v * 9 / 5 + 32) + " °F" : Math.round(v) + " °C";
    }
    function speed(bytes) {
        var v = cfg.netBits ? bytes * 8 : bytes, step = cfg.netBits ? 1000 : 1024;
        var units = cfg.netBits ? ["b/s", "kb/s", "Mb/s", "Gb/s"] : ["B/s", "KiB/s", "MiB/s", "GiB/s"];
        var i = 0;
        while (v >= step && i < units.length - 1) { v /= step; i++; }
        return dec(v, i > 0 && v < 10 ? 1 : 0) + " " + units[i];
    }
    function span(ms) {
        var m = Math.max(0, Math.round(ms / 60000));
        if (m < 60) return m + " min";
        if (m < 1440) return Math.floor(m / 60) + " h " + (m % 60) + " min";
        return Math.floor(m / 1440) + " d " + Math.floor((m % 1440) / 60) + " h";
    }
    function limitName(kind) { return ({ five_hour: tr("Sesja 5 h"), seven_day: tr("Tydzień") })[kind] || kind.replace(/_/g, " "); }
    function profileName(p) { return ({ performance: tr("Wydajność"), balanced: tr("Zrównoważony"), "power-saver": tr("Oszczędzanie") })[p] || ""; }
    // Tekst jako jeden argument powłoki.
    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    readonly property int rate: Math.max(1, cfg.interval) * 1000
    // Karta: z ustawień, potem z pliku ~/.config/wydma/gpu, na końcu pierwsza w systemie.
    readonly property string gpu: cfg.gpu || status.gpu || "gpu/gpu0"
    readonly property string net: "network/" + (cfg.netIface || "all")
    readonly property string diskId: "disk/" + (cfg.disk || "all")

    Sensors.Sensor { id: cpu; sensorId: "cpu/all/usage"; updateRateLimit: root.rate }
    Sensors.Sensor { id: cpuTemp; sensorId: "cpu/all/averageTemperature"; updateRateLimit: Math.max(2000, root.rate) }
    // Odczyt NVIDII idzie przez nvidia-smi, który nie pozwala karcie zasnąć, więc domyślnie tylko na zasilaczu.
    readonly property bool gpuLive: cfg.gpuOnBattery || status.ac === 1
    function gpuNum(s) { return gpuLive ? num(s) : 0; }
    Sensors.Sensor { id: gpuUse; sensorId: root.gpu + "/usage"; updateRateLimit: Math.max(2000, root.rate); enabled: root.gpuLive }
    Sensors.Sensor { id: gpuTemp; sensorId: root.gpu + "/temperature"; updateRateLimit: Math.max(2000, root.rate); enabled: root.gpuLive }
    Sensors.Sensor { id: vramUsed; sensorId: root.gpu + "/usedVram"; updateRateLimit: Math.max(2000, root.rate); enabled: root.gpuLive }
    Sensors.Sensor { id: vramTotal; sensorId: root.gpu + "/totalVram"; enabled: root.gpuLive }
    Sensors.Sensor { id: gpuName; sensorId: root.gpu + "/name"; enabled: root.gpuLive }
    // Nazwa karty zostaje po przejściu na baterię, kiedy odczyt jest wyłączony.
    property string gpuTitle: ""
    readonly property string gpuSeen: gpuLive && gpuName.status === Sensors.Sensor.Ready && gpuName.value ? String(gpuName.value).replace(/^(NVIDIA|AMD|Intel)\s+(GeForce\s+)?/i, "") : ""
    onGpuSeenChanged: if (gpuSeen) gpuTitle = gpuSeen
    Sensors.Sensor { id: ram; sensorId: "memory/physical/usedPercent"; updateRateLimit: root.rate }
    Sensors.Sensor { id: ramUsed; sensorId: "memory/physical/used"; updateRateLimit: root.rate }
    Sensors.Sensor { id: ramTotal; sensorId: "memory/physical/total" }
    Sensors.Sensor { id: swap; sensorId: "memory/swap/usedPercent"; updateRateLimit: Math.max(2000, root.rate); enabled: root.cfg.showSwap }
    Sensors.Sensor { id: swapUsed; sensorId: "memory/swap/used"; updateRateLimit: Math.max(2000, root.rate); enabled: root.cfg.showSwap }
    Sensors.Sensor { id: swapTotal; sensorId: "memory/swap/total"; enabled: root.cfg.showSwap }
    Sensors.Sensor { id: disk; sensorId: root.diskId + "/usedPercent"; updateRateLimit: 10000 }
    Sensors.Sensor { id: diskFree; sensorId: root.diskId + "/free"; updateRateLimit: 10000 }
    Sensors.Sensor { id: netDown; sensorId: root.net + "/download"; updateRateLimit: root.rate }
    Sensors.Sensor { id: netUp; sensorId: root.net + "/upload"; updateRateLimit: root.rate }
    Sensors.Sensor { id: osName; sensorId: "os/system/prettyName"; enabled: root.has("system") }
    Sensors.Sensor { id: osKernel; sensorId: "os/kernel/prettyName"; enabled: root.has("system") }
    Sensors.Sensor { id: osHost; sensorId: "os/system/hostname"; enabled: root.has("system") }
    Sensors.Sensor { id: osPlasma; sensorId: "os/plasma/plasmaVersion"; enabled: root.has("system") }
    Sensors.Sensor { id: osUptime; sensorId: "os/system/uptime"; updateRateLimit: 60000; enabled: root.has("system") }

    // Bez sekund na zegarze wystarczy takt czujników. Kafelki liczące czas do zdarzeń (plan, limity)
    // patrzą na root.minute, więc przeliczają się raz na minutę, a nie przy każdym takcie.
    property var minute: new Date()
    Timer {
        interval: root.cfg.seconds ? 1000 : root.rate; repeat: true; running: true; triggeredOnStart: true
        onTriggered: {
            root.now = new Date();
            if (root.now.getMinutes() !== root.minute.getMinutes() || root.now - root.minute >= 60000) root.minute = root.now;
            root.down = root.down.concat([root.num(netDown)]).slice(-40);
            root.up = root.up.concat([root.num(netUp)]).slice(-40);
        }
    }

    // VPN. Ze skryptem ~/.local/bin/protonvpn-auto steruje on Protonem i pilnuje sieci bez VPN-a;
    // bez niego lista łączy profile NetworkManagera wprost. Kliknięcie aktywnej pozycji rozłącza.
    property bool vpnBusy: false
    property bool vpnRolling: false
    readonly property bool vpnTool: status.hasVpn === 1
    readonly property string vpnCmd: "\"$HOME/.local/bin/protonvpn-auto\" "
    readonly property string protonName: "Proton VPN"
    readonly property string vpnNow: !status.vpn ? "" : vpnTool && status.vpn.indexOf("ProtonVPN") === 0 ? protonName : status.vpn
    readonly property var vpnList: (vpnTool ? [protonName] : []).concat(status.vpns || [])
    property string vpnPick
    property string vpnFailed
    // Nowe IP: inny losowy serwer Protona w tym samym kraju.
    function rollVpn() {
        vpnBusy = true;
        vpnRolling = true;
        vpnPick = "";
        vpnFailed = "";
        vpnExec.connectSource(vpnCmd + "roll");
    }
    function toggleVpn(on) {
        vpnBusy = true;
        vpnPick = "";
        vpnFailed = "";
        if (vpnTool) vpnExec.connectSource(vpnCmd + (on ? "on" : "off"));
        else if (on) pickVpn(vpnList[0] || "");
        else vpnExec.connectSource("nmcli con down id " + q(status.vpn));
    }
    // Łączenie może czekać na okno logowania.
    function pickVpn(name) {
        if (!name) { vpnBusy = false; return; }
        vpnBusy = true;
        vpnPick = name;
        vpnFailed = "";
        vpnExec.connectSource(vpnTool ? vpnCmd + "select " + q(name) : "nmcli --wait 110 con up id " + q(name));
    }
    P5Support.DataSource {
        id: vpnExec
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            root.vpnBusy = false;
            root.vpnRolling = false;
            if (root.vpnPick && data["exit code"] !== 0) root.vpnFailed = root.vpnPick;
            root.vpnPick = "";
            root.refresh(true);
        }
    }
    // Sieci bez VPN-a z ustawień trafiają do pliku, który czyta skrypt protonvpn-auto.
    readonly property string novpn: cfg.novpn
    onNovpnChanged: {
        var names = novpn.split(",").map(n => n.trim()).filter(n => n);
        launcher.connectSource("mkdir -p \"$HOME/.config/wydma\" && printf '%s\\n' " + ["# Wi-Fi bez VPN-a (zapisuje widżet Wydma)"].concat(names).map(q).join(" ") + " > \"$HOME/.config/wydma/novpn\"");
    }

    // Tryb ładowania: /usr/local/sbin/battery-mode przez sudo bez hasła, potem szybkie odświeżenie stanu.
    property bool chargeBusy: false
    property bool chargeFailed: false
    readonly property var chargeModes: [
        { arg: "long", value: "Long_Life", label: tr("Ochrona"), hint: tr("ładowanie zatrzymuje się w okolicach 80%") },
        { arg: "standard", value: "Standard", label: tr("Standard"), hint: tr("ładowanie do 100%") },
        { arg: "fast", value: "Fast", label: tr("Szybkie"), hint: tr("szybko do 100%, mocniej grzeje baterię") }
    ]
    property string chargePick
    property string chargeDone
    function setCharge(arg, label) {
        chargeBusy = true;
        chargeFailed = false;
        chargeDone = "";
        chargePick = label;
        chargeExec.connectSource("sudo -n /usr/local/sbin/battery-mode " + arg);
    }
    // Skrypt odczytuje tryb z powrotem, więc kod 0 oznacza potwierdzoną zmianę.
    P5Support.DataSource {
        id: chargeExec
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            root.chargeBusy = false;
            root.chargeFailed = data["exit code"] !== 0;
            if (!root.chargeFailed) { root.chargeDone = root.chargePick; chargeDoneTimer.restart(); }
            root.refresh(false);
        }
    }
    Timer { id: chargeDoneTimer; interval: 6000; onTriggered: root.chargeDone = "" }

    // Tryb grafiki: zapis w firmware przez /usr/local/sbin/gpu-mode, działa dopiero po restarcie.
    // Przy przejściu do iGPU albo z niego skrypt przebudowuje initramfs (ok. 20 s), więc wybrany tryb
    // podświetlamy od razu i piszemy, że trwa zapis.
    property bool gpuBusy: false
    property bool gpuFailed: false
    property string gpuWanted: ""
    readonly property var gpuModes: [
        { arg: "hybrid", value: "hybrid", label: "Hybrid", hint: tr("ekran na Intelu, NVIDIA włącza się w razie potrzeby") },
        { arg: "igpu", value: "igpu", label: "iGPU", hint: tr("tylko Intel, monitor zewnętrzny może nie działać") },
        { arg: "dgpu", value: "dgpu", label: "dGPU", hint: tr("wszystko na NVIDII, G-Sync, większy pobór prądu") }
    ]
    function gpuLabel(v) { var m = gpuModes.find(x => x.value === v); return m ? m.label : "—"; }
    function setGpu(arg) {
        gpuBusy = true;
        gpuFailed = false;
        gpuWanted = arg;
        gpuTimeout.restart();
        gpuExec.connectSource("sudo -n /usr/local/sbin/gpu-mode " + arg);
    }
    // Bezpiecznik: gdyby skrypt nie odpowiedział, po 3 min odblokuj przyciski i pokaż stan z systemu.
    Timer {
        id: gpuTimeout
        interval: 180000
        onTriggered: { root.gpuBusy = false; root.gpuWanted = ""; root.refresh(false); }
    }
    P5Support.DataSource {
        id: gpuExec
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            gpuTimeout.stop();
            root.gpuBusy = false;
            root.gpuWanted = "";
            root.gpuFailed = data["exit code"] !== 0;
            root.refresh(false);
        }
    }

    // Limity Claude, zasilanie, VPN, słuchawki i procesy z jednego skryptu: lekki odczyt w takcie
    // czujników, ale nie częściej niż co 10 s, i mniej więcej raz na minutę pełny (z listą profili VPN).
    readonly property string statusCmd: (cfg.usageFile ? "WYDMA_USAGE=" + q(cfg.usageFile) + " " : "")
        + "sh " + q(Qt.resolvedUrl("../code/status.sh").toString().replace("file://", ""))
    function refresh(full) { exec.connectSource(statusCmd + (full ? " full" : "") + (has("procs") ? " procs" : "")); }
    // Ostatni odczyt: ten sam stan nie podmienia root.status, więc kafelki się nie przeliczają.
    property string lastStatus: ""
    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            try {
                var next = JSON.parse(data["stdout"]);
                // Lista VPN-ów przychodzi tylko w pełnym odczycie; między nimi zostaje poprzednia.
                if (next.vpns === null) next.vpns = root.status.vpns || [];
                var key = JSON.stringify(next);
                if (key !== root.lastStatus) { root.lastStatus = key; root.status = next; }
            } catch (e) {}
            disconnectSource(source);
        }
    }
    property int ticks: 0
    readonly property int statusRate: Math.max(10000, rate)
    Timer {
        interval: root.statusRate; repeat: true; running: true; triggeredOnStart: true
        onTriggered: root.refresh(root.ticks++ % Math.max(1, Math.round(60000 / root.statusRate)) === 0)
    }

    // Plan co 3 godziny (i przy starcie): polecenie z ustawień albo program ~/.config/wydma/plan. Podaje jedną linię JSON
    // { pobrano, zajecia: [{ przedmiot, forma, start, koniec, sala, budynek, uwaga }] }; bez niego kafelka nie ma.
    property var plan: null
    readonly property string planCmd: cfg.planCommand ? "( " + cfg.planCommand + " ) 2>/dev/null || echo null"
        : "sh -c 'p=\"$HOME/.config/wydma/plan\"; [ -x \"$p\" ] && \"$p\" || echo null'"
    P5Support.DataSource {
        id: planExec
        engine: "executable"
        onNewData: (source, data) => {
            try { root.plan = JSON.parse(data["stdout"]); } catch (e) { root.plan = null; }
            disconnectSource(source);
        }
    }
    Timer {
        interval: 3 * 3600000; repeat: true; running: root.has("plan"); triggeredOnStart: true
        onTriggered: planExec.connectSource(root.planCmd)
    }
    onPlanCmdChanged: if (has("plan")) planExec.connectSource(planCmd)

    // Własny kafelek: wynik dowolnego polecenia, odświeżany co ustawiony czas.
    property string customText: ""
    P5Support.DataSource {
        id: customExec
        engine: "executable"
        onNewData: (source, data) => {
            root.customText = String(data["stdout"] || "").replace(/\s+$/, "").split("\n").slice(0, 8).join("\n");
            disconnectSource(source);
        }
    }
    readonly property bool customOn: has("custom") && cfg.customCommand !== ""
    Timer {
        interval: Math.max(5, root.cfg.customInterval) * 1000; repeat: true; running: root.customOn; triggeredOnStart: true
        onTriggered: customExec.connectSource(root.cfg.customCommand)
    }

    P5Support.DataSource {
        id: launcher
        engine: "executable"
        onNewData: (source, data) => disconnectSource(source)
    }
    function run(command) { launcher.connectSource("setsid -f " + command + " >/dev/null 2>&1"); }
    function openPlan() {
        if (cfg.planOpen) run(cfg.planOpen);
        else launcher.connectSource("sh -c 'p=\"$HOME/.config/wydma/plan-open\"; [ -x \"$p\" ] && setsid -f \"$p\" >/dev/null 2>&1'");
    }

    function formName(f) { return ({ W: tr("wykład"), L: tr("laboratorium"), C: tr("ćwiczenia"), P: tr("projekt"), S: tr("seminarium") })[f] || f; }
    function hm(iso) { return Qt.formatTime(new Date(Date.parse(iso)), root.cfg.clock12 ? "h:mm AP" : "HH:mm"); }
    // „dziś”, „jutro” albo skrót dnia tygodnia z datą.
    function dayName(iso) {
        var day = new Date(Date.parse(iso)), today = new Date(root.now);
        day.setHours(0, 0, 0, 0);
        today.setHours(0, 0, 0, 0);
        var diff = Math.round((day - today) / 86400000);
        if (diff === 0) return tr("dziś");
        if (diff === 1) return tr("jutro");
        return new Date(Date.parse(iso)).toLocaleDateString(root.loc, "ddd d.MM");
    }

    function cardOf(name) {
        return ({ clock: clockCard, plan: planCard, claude: claudeCard, cpu: cpuCard, memory: memoryCard, network: networkCard,
                  power: powerCard, gpumode: gpuModeCard, vpn: vpnCard, system: systemCard, procs: procsCard, notes: notesCard,
                  custom: customCard })[name] || null;
    }

    component Line: RowLayout {
        id: line
        property string name
        property string value
        property Theme theme: pal
        Layout.fillWidth: true
        spacing: 10
        Txt { text: line.name; color: line.theme.muted; font.pixelSize: 12 }
        Txt { text: line.value; color: line.theme.ink; font.pixelSize: 12; font.weight: Font.Medium; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
    }

    // Zegar. Poza warstwami sam tekst na tapecie; w warstwach pierwsza, najjaśniejsza warstwa stosu,
    // z godziną i datą w jednym rzędzie.
    Component {
        id: clockCard
        Card {
            id: clock
            theme: pal
            bare: true
            readonly property bool leftSide: root.cfg.align === "left"
            readonly property string time: Qt.formatTime(root.now, root.cfg.clock12 ? (root.cfg.seconds ? "h:mm:ss AP" : "h:mm AP") : (root.cfg.seconds ? "HH:mm:ss" : "HH:mm"))
            readonly property color tone: root.cfg.darkClock ? "#2a2018" : "white"
            // Poza warstwami jak dawniej: kolumna dosunięta do wybranej krawędzi.
            Item {
                visible: !clock.layered
                Layout.fillWidth: true
                implicitHeight: classic.implicitHeight
                ColumnLayout {
                    id: classic
                    x: clock.leftSide ? 6 : parent.width - width - 6
                    spacing: -4
                    Txt {
                        Layout.alignment: clock.leftSide ? Qt.AlignLeft : Qt.AlignRight
                        text: clock.time
                        color: clock.tone
                        font.pixelSize: root.cfg.clockSize; font.weight: Font.Light; font.features: { "tnum": 1 }
                        style: Text.Raised; styleColor: root.cfg.darkClock ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0.25, 0.15, 0.05, 0.25)
                    }
                    Txt {
                        Layout.alignment: clock.leftSide ? Qt.AlignLeft : Qt.AlignRight
                        visible: root.cfg.showDate
                        text: root.cfg.dateFormat === "iso" ? Qt.formatDate(root.now, "yyyy-MM-dd")
                            : root.cfg.dateFormat === "short" ? root.now.toLocaleDateString(root.loc, "ddd, d MMM")
                            : root.now.toLocaleDateString(root.loc, "dddd, d MMMM")
                        color: clock.tone
                        font.pixelSize: Math.max(11, root.cfg.clockSize / 4); font.weight: Font.Medium
                        style: Text.Raised; styleColor: root.cfg.darkClock ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0.25, 0.15, 0.05, 0.3)
                    }
                }
            }
            // Warstwy: godzina przy lewej krawędzi, dzień tygodnia nad datą przy prawej, pod spodem wydma doby.
            readonly property int big: Math.round(root.cfg.clockSize * 1.25)
            readonly property int small: Math.max(12, Math.round(root.cfg.clockSize * 0.25))
            RowLayout {
                visible: clock.layered
                Layout.fillWidth: true
                spacing: 10
                Txt {
                    id: strataTime
                    text: clock.time
                    face: look.display
                    color: look.ink
                    font.pixelSize: clock.big; font.weight: Font.Light; font.features: { "tnum": 1 }
                    font.letterSpacing: -clock.big * 0.03
                    Layout.leftMargin: -clock.big * 0.03
                }
                Item { Layout.fillWidth: true }
                ColumnLayout {
                    visible: root.cfg.showDate
                    spacing: 0
                    Layout.alignment: Qt.AlignBottom
                    // Dolna linia daty siedzi na linii pisma godziny.
                    Layout.bottomMargin: (strataTime.height - strataTime.baselineOffset) - (strataDate.height - strataDate.baselineOffset)
                    Txt {
                        Layout.alignment: Qt.AlignRight
                        text: root.now.toLocaleDateString(root.loc, "dddd")
                        face: look.display; color: look.clay
                        font.pixelSize: clock.small; font.weight: Font.DemiBold
                    }
                    Txt {
                        id: strataDate
                        Layout.alignment: Qt.AlignRight
                        text: root.cfg.dateFormat === "iso" ? Qt.formatDate(root.now, "yyyy-MM-dd")
                            : root.now.toLocaleDateString(root.loc, root.cfg.dateFormat === "short" ? "d MMM" : "d MMMM")
                        face: look.display; color: look.muted
                        font.pixelSize: clock.small
                    }
                }
            }
            DayDune {
                visible: clock.layered
                Layout.fillWidth: true
                Layout.topMargin: 2
                progress: (root.minute.getHours() * 60 + root.minute.getMinutes()) / 1440
                color: look.clay
                tick: look.ink
            }
        }
    }

    // Plan: najbliższe zajęcia albo spotkania
    Component {
        id: planCard
        Card {
            id: classCard
            theme: pal
            shown: root.plan !== null
            title: root.cfg.planTitle || root.tr("Zajęcia")
            accent: look.teal
            readonly property var list: root.plan && root.plan.zajecia ? root.plan.zajecia.filter(z => Date.parse(z.koniec) > root.minute) : []
            readonly property var cur: list.length ? list[0] : null
            readonly property real startMs: cur ? Date.parse(cur.start) : 0
            readonly property bool live: cur !== null && startMs <= root.minute
            note: !cur ? "" : live ? root.tr("trwa") : root.dayName(cur.start)
            // Kolumna z terminem kolejnych zajęć ma szerokość najdłuższego wpisu:
            // dzień tygodnia z datą nie mieści się w stałej szerokości.
            readonly property var nextDates: list.slice(1, 1 + Math.max(0, root.cfg.planCount)).map(c => root.dayName(c.start) + " " + root.hm(c.start))
            readonly property real dateW: Math.ceil(nextDates.reduce((w, t) => Math.max(w, dateMetrics.advanceWidth(t)), 0)) + 2
            FontMetrics {
                id: dateMetrics
                font.pixelSize: classCard.layered ? 13 : 12
                font.family: Plasmoid.configuration.fontFamily || Qt.application.font.family
                font.features: { "tnum": 1 }
            }

            // Kliknięcie w kafelek otwiera aplikację z planem.
            clickable: true
            onTapped: root.openPlan()

            // Warstwy: termin nad tytułem, pod nim forma i miejsce.
            function cap(t) { return t ? t.charAt(0).toUpperCase() + t.slice(1) : ""; }
            ColumnLayout {
                Layout.fillWidth: true
                visible: classCard.layered && classCard.cur !== null
                spacing: 2
                Txt {
                    Layout.fillWidth: true
                    text: !classCard.cur ? "" : classCard.live ? root.tr("Trwa · do %1", root.hm(classCard.cur.koniec))
                        : classCard.cap(root.dayName(classCard.cur.start)) + " · " + root.hm(classCard.cur.start) + "–" + root.hm(classCard.cur.koniec)
                    face: look.display; color: look.clay; font.pixelSize: 14; font.weight: Font.DemiBold
                }
                Txt {
                    Layout.fillWidth: true
                    text: classCard.cur ? classCard.cur.przedmiot : ""
                    face: look.display; color: look.ink; font.pixelSize: 18; font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                }
                Txt {
                    Layout.fillWidth: true
                    readonly property var where: classCard.cur ? [classCard.cap(root.formName(classCard.cur.forma || "")), classCard.cur.sala ? root.tr("sala %1", classCard.cur.sala) : "", classCard.cur.budynek, classCard.cur.uwaga].filter(p => p) : []
                    visible: where.length > 0
                    text: where.join(" · ")
                    color: look.muted; font.pixelSize: 13; wrapMode: Text.WordWrap
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: !classCard.layered && classCard.cur !== null
                spacing: 12
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    visible: !!classCard.cur && !!classCard.cur.forma
                    implicitWidth: 34; implicitHeight: 34; radius: 10
                    color: look.tint(look.teal, 0.16)
                    Txt { anchors.centerIn: parent; text: classCard.cur ? classCard.cur.forma || "" : ""; color: look.teal; font.pixelSize: 15; font.weight: Font.DemiBold }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Txt {
                        Layout.fillWidth: true
                        text: classCard.cur ? classCard.cur.przedmiot : ""
                        color: look.ink; font.pixelSize: 15; font.weight: Font.Medium
                        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                    }
                    Txt {
                        Layout.fillWidth: true
                        text: classCard.cur ? root.dayName(classCard.cur.start) + " " + root.hm(classCard.cur.start) + "–" + root.hm(classCard.cur.koniec)
                            + (classCard.cur.forma ? " · " + root.formName(classCard.cur.forma) : "") : ""
                        color: look.muted; font.pixelSize: 12
                    }
                    Txt {
                        Layout.fillWidth: true
                        readonly property var where: classCard.cur ? [classCard.cur.sala ? root.tr("sala %1", classCard.cur.sala) : "", classCard.cur.budynek, classCard.cur.uwaga].filter(p => p) : []
                        visible: where.length > 0
                        text: where.join(" · ")
                        color: look.faint; font.pixelSize: 12; elide: Text.ElideRight
                    }
                }
            }
            // Kolejne pozycje
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: look.track; visible: classCard.list.length > 1 && root.cfg.planCount > 0 }
            Repeater {
                model: Math.min(root.cfg.planCount, Math.max(0, classCard.list.length - 1))
                delegate: RowLayout {
                    required property int index
                    readonly property var cls: classCard.list[index + 1] || null
                    Layout.fillWidth: true
                    spacing: classCard.layered ? 10 : 8
                    Txt {
                        text: classCard.nextDates[index] || ""
                        color: look.muted; font.pixelSize: classCard.layered ? 13 : 12; font.features: { "tnum": 1 }
                        Layout.preferredWidth: classCard.dateW
                        Layout.alignment: Qt.AlignTop
                    }
                    // W warstwach nazwa w całości, a forma i sala w drugiej linii.
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Txt {
                            Layout.fillWidth: true
                            text: !cls ? "" : classCard.layered ? cls.przedmiot : cls.przedmiot + (cls.forma ? " (" + cls.forma + ")" : "")
                            color: look.ink; font.pixelSize: classCard.layered ? 13 : 12
                            wrapMode: classCard.layered ? Text.WordWrap : Text.NoWrap
                            elide: Text.ElideRight
                        }
                        Txt {
                            Layout.fillWidth: true
                            visible: classCard.layered && text !== ""
                            text: cls ? [root.formName(cls.forma || ""), cls.sala ? root.tr("sala %1", cls.sala) : ""].filter(p => p).join(" · ") : ""
                            color: look.muted; font.pixelSize: 13
                        }
                    }
                    Txt { visible: !classCard.layered; text: cls ? cls.sala || "" : ""; color: look.faint; font.pixelSize: 12; Layout.alignment: Qt.AlignTop }
                }
            }
            Txt {
                visible: !classCard.cur
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.tr("Nic zaplanowanego.")
                color: look.muted; font.pixelSize: 12
            }
            Txt {
                visible: !!root.plan && !!root.plan.pobrano && root.minute - Date.parse(root.plan.pobrano) > 3 * 86400000
                Layout.fillWidth: true
                text: visible ? root.tr("plan z %1, do odświeżenia", new Date(Date.parse(root.plan.pobrano)).toLocaleDateString(root.loc, "d.MM")) : ""
                color: look.warn; font.pixelSize: classCard.layered ? 13 : 11
            }
        }
    }

    // Limity Claude
    Component {
        id: claudeCard
        Card {
            id: claude
            theme: pal
            title: root.tr("Limity Claude")
            accent: look.clay
            readonly property var usage: root.status.usage || null
            note: usage ? root.tr("odczyt %1 temu", root.span(root.minute - usage.at)) : ""
            // Warstwy: limity obok siebie jako duże liczby z wydmą.
            GridLayout {
                Layout.fillWidth: true
                visible: claude.layered && !!claude.usage
                columns: 2
                columnSpacing: 18
                rowSpacing: 12
                Repeater {
                    model: claude.layered && claude.usage ? claude.usage.limits.length : 0
                    delegate: Stat {
                        required property int index
                        readonly property var lim: claude.usage ? claude.usage.limits[index] : null
                        theme: look
                        label: lim ? "Claude · " + root.limitName(lim.kind).toLowerCase() : ""
                        value: lim ? lim.percent : 0
                        detail: lim && lim.resetsAt ? root.tr("reset za %1", root.span(Date.parse(lim.resetsAt) - root.minute)) : ""
                        dune: true
                        seed: index
                    }
                }
            }
            Repeater {
                model: !claude.layered && claude.usage ? claude.usage.limits.length : 0
                delegate: MeterRow {
                    required property int index
                    readonly property var lim: claude.usage ? claude.usage.limits[index] : null
                    theme: look
                    name: lim ? root.limitName(lim.kind) : ""
                    detail: lim && lim.resetsAt ? root.tr("reset za %1", root.span(Date.parse(lim.resetsAt) - root.minute)) : ""
                    value: lim ? lim.percent : 0
                    color: look.clay
                    nameSize: 14
                    barHeight: 8
                }
            }
            Txt {
                visible: !claude.usage
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.tr("Brak odczytu. Pojawi się po pierwszej odpowiedzi Claude (potrzebna wtyczka Claudbar).")
                color: look.muted; font.pixelSize: 12
            }
        }
    }

    // CPU i GPU
    Component {
        id: cpuCard
        Card {
            theme: pal
            title: root.tr("Procesor i grafika")
            accent: look.sky
            note: root.gpuLive ? root.gpuTitle : (root.gpuTitle ? root.gpuTitle + ", " : "") + root.tr("odczyt na zasilaczu")
            readonly property color cpuHot: root.num(cpuTemp) >= root.cfg.tempAlert ? look.alert : root.num(cpuTemp) >= root.cfg.tempWarn ? look.warn : look.muted
            readonly property color gpuHot: root.gpuNum(gpuTemp) >= root.cfg.tempAlert ? look.alert : root.gpuNum(gpuTemp) >= root.cfg.tempWarn ? look.warn : look.muted
            RowLayout {
                Layout.fillWidth: true
                visible: layered
                spacing: 18
                Stat { theme: look; label: root.tr("Procesor"); value: root.num(cpu); detail: root.temp(cpuTemp); detailColor: cpuHot }
                Stat {
                    theme: look; label: root.tr("Grafika"); value: root.gpuNum(gpuUse); detailColor: gpuHot
                    detail: root.gpuLive ? [root.temp(gpuTemp), root.gpuTitle].filter(p => p).join(" · ") : root.tr("odczyt na zasilaczu")
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: !layered
                Gauge { theme: look; name: "CPU"; value: root.num(cpu); temp: root.num(cpuTemp); tempText: root.temp(cpuTemp); tempWarn: root.cfg.tempWarn; tempAlert: root.cfg.tempAlert; color: look.sky }
                Gauge { theme: look; name: "GPU"; value: root.gpuNum(gpuUse); temp: root.gpuNum(gpuTemp); tempText: root.gpuLive ? root.temp(gpuTemp) : "—"; tempWarn: root.cfg.tempWarn; tempAlert: root.cfg.tempAlert; color: look.sage }
            }
            clickable: root.cfg.clickActions
            onTapped: root.run("plasma-systemmonitor")
        }
    }

    // Pamięć i dysk
    Component {
        id: memoryCard
        Card {
            theme: pal
            title: root.tr("Pamięć")
            accent: look.dusk
            MeterRow { theme: look; name: "RAM"; value: root.num(ram); detail: root.gib(root.num(ramUsed)) + " / " + root.gib(root.num(ramTotal)) + " GiB"; color: look.dusk }
            MeterRow {
                theme: look; visible: root.cfg.showSwap && root.num(swapTotal) > 0
                name: root.tr("Wymiana"); value: root.num(swap); detail: root.gib(root.num(swapUsed)) + " / " + root.gib(root.num(swapTotal)) + " GiB"; color: look.teal
            }
            MeterRow {
                theme: look; visible: root.cfg.showVram
                name: "VRAM"; value: root.gpuNum(vramTotal) > 0 ? 100 * root.gpuNum(vramUsed) / root.gpuNum(vramTotal) : 0
                detail: root.gpuLive ? root.txt(vramUsed) + " / " + root.txt(vramTotal) : "—"; color: look.sage
            }
            MeterRow { theme: look; name: root.tr("Dysk"); value: root.num(disk); detail: root.tr("wolne %1", root.txt(diskFree)); color: look.gold }
            clickable: root.cfg.clickActions
            onTapped: root.run("plasma-systemmonitor")
        }
    }

    // Sieć
    Component {
        id: networkCard
        Card {
            theme: pal
            title: root.tr("Sieć")
            accent: look.sky
            note: root.cfg.netIface && root.cfg.netIface !== "all" ? root.cfg.netIface : ""
            RowLayout {
                Layout.fillWidth: true
                visible: !layered
                Txt { text: "↓ " + root.speed(root.num(netDown)); color: look.sky; font.pixelSize: 15; font.weight: Font.Medium; font.features: { "tnum": 1 } }
                Item { Layout.fillWidth: true }
                Txt { text: "↑ " + root.speed(root.num(netUp)); color: look.clay; font.pixelSize: 15; font.weight: Font.Medium; font.features: { "tnum": 1 } }
            }
            // Warstwy: legenda z kropkami zamiast strzałek.
            RowLayout {
                Layout.fillWidth: true
                visible: layered
                spacing: 7
                Rectangle { implicitWidth: 7; implicitHeight: 7; radius: 4; color: look.sky }
                Txt { text: root.tr("pobieranie") + " <b>" + root.speed(root.num(netDown)) + "</b>"; textFormat: Text.StyledText; color: look.ink; font.pixelSize: 13; font.features: { "tnum": 1 } }
                Item { Layout.fillWidth: true }
                Rectangle { implicitWidth: 7; implicitHeight: 7; radius: 4; color: look.clay }
                Txt { text: root.tr("wysyłanie") + " <b>" + root.speed(root.num(netUp)) + "</b>"; textFormat: Text.StyledText; color: look.ink; font.pixelSize: 13; font.features: { "tnum": 1 } }
            }
            Spark { Layout.fillWidth: true; visible: root.cfg.netGraph; series: [root.down, root.up]; colors: [look.sky, look.clay]; fillAlpha: layered ? 0.22 : 0.12; implicitHeight: layered ? 40 : 46 }
            clickable: root.cfg.clickActions
            onTapped: root.run("kcmshell6 kcm_networkmanagement")
        }
    }

    // Zasilanie
    Component {
        id: powerCard
        Card {
            id: power
            theme: pal
            title: root.tr("Zasilanie")
            accent: look.gold
            readonly property bool hasBat: root.status.bat !== undefined && root.status.bat !== null
            readonly property real bat: root.status.bat || 0
            readonly property bool ac: root.status.ac === 1
            readonly property bool hasHeadset: root.status.headsetPct !== undefined && root.status.headsetPct !== null
            shown: hasBat || hasHeadset || root.profileName(root.status.profile) !== ""
            note: root.profileName(root.status.profile)
            // Opis trybu ładowania albo wynik jego zmiany; w warstwach stoi pod tytułem.
            readonly property var chargeMode: root.chargeModes.find(m => m.value === root.status.charge)
            readonly property string chargeText: root.status.hasCharge !== 1 ? ""
                : root.chargeFailed ? "⚠ " + root.tr("Nie udało się zmienić trybu ładowania.")
                : root.chargeDone ? "✓ " + root.tr("Włączono: %1", root.chargeDone)
                : chargeMode ? chargeMode.hint : ""
            readonly property color chargeColor: root.chargeFailed ? look.alert : root.chargeDone ? look.sage : look.faint
            readonly property color batColor: bat <= 15 ? look.alert : bat <= 30 ? look.warn : look.ink
            RowLayout {
                Layout.fillWidth: true
                visible: power.layered
                spacing: 12
                Icon { name: power.ac || !power.hasBat ? "plug" : "battery"; color: look.ink; size: 18; Layout.alignment: Qt.AlignVCenter }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Txt {
                        Layout.fillWidth: true
                        text: !power.hasBat ? root.tr("Zasilanie sieciowe") : (power.ac ? root.tr("Zasilacz") : root.tr("Bateria"))
                            + (!power.ac && root.status.watts > 0.5 ? " · " + root.dec(root.status.watts, 1) + " W" : "")
                        face: look.display; color: look.ink; font.pixelSize: 18; font.weight: Font.DemiBold; elide: Text.ElideRight
                    }
                    Txt {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: power.chargeText
                        color: root.chargeFailed || root.chargeDone ? power.chargeColor : look.muted
                        font.pixelSize: 13; wrapMode: Text.WordWrap
                    }
                }
                RowLayout {
                    visible: power.hasBat
                    spacing: 2
                    Txt { text: Math.round(power.bat); face: look.display; color: power.batColor; font.pixelSize: 38; font.weight: Font.Light; font.features: { "tnum": 1 }; Layout.alignment: Qt.AlignBaseline }
                    Txt { text: "%"; face: look.display; color: look.muted; font.pixelSize: 18; Layout.alignment: Qt.AlignBaseline }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: power.hasBat && !power.layered
                Txt {
                    text: (power.ac ? "🔌 " + root.tr("Zasilacz") : "🔋 " + root.tr("Bateria"))
                        + (!power.ac && root.status.watts > 0.5 ? " · " + root.dec(root.status.watts, 1) + " W" : "")
                    color: look.ink; font.pixelSize: 13; font.weight: Font.Medium
                }
                Item { Layout.fillWidth: true }
                Txt { text: root.pct(power.bat); color: power.bat <= 15 ? look.alert : power.bat <= 30 ? look.warn : look.ink; font.pixelSize: 13; font.weight: Font.DemiBold }
            }
            Bar { Layout.fillWidth: true; visible: power.hasBat && !power.layered; implicitHeight: 6; value: power.bat; color: power.bat <= 15 ? look.alert : power.bat <= 30 ? look.warn : look.sage; track: look.track }
            Txt {
                visible: !power.hasBat && !power.hasHeadset && !power.layered
                text: "🔌 " + root.tr("Zasilanie sieciowe")
                color: look.ink; font.pixelSize: 13; font.weight: Font.Medium
            }
            // Tryb ładowania
            ModeRow {
                theme: look
                visible: root.status.hasCharge === 1
                modes: root.chargeModes
                current: root.status.charge || ""
                busy: root.chargeBusy
                accent: power.layered ? look.ink : look.gold
                Layout.topMargin: power.layered ? 4 : 0
                onPicked: (arg, label) => root.setCharge(arg, label)
            }
            Txt {
                Layout.fillWidth: true
                visible: root.status.hasCharge === 1 && !power.layered
                wrapMode: Text.WordWrap
                text: power.chargeText
                color: power.chargeColor
                font.pixelSize: 11
            }
            RowLayout {
                Layout.fillWidth: true
                visible: power.hasHeadset
                Layout.topMargin: power.layered ? 4 : 0
                spacing: power.layered ? 12 : 5
                Icon { visible: power.layered; name: "headset"; color: look.ink; size: 18 }
                Txt { text: (power.layered ? "" : "🎧 ") + (root.status.headset || root.tr("Słuchawki")); color: look.ink; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                Txt {
                    readonly property real charge: root.status.headsetPct || 0
                    text: root.pct(charge); color: charge <= 15 ? look.alert : charge <= 30 ? look.warn : look.ink; font.pixelSize: 13; font.weight: Font.DemiBold
                }
            }
        }
    }

    // Tryb grafiki
    Component {
        id: gpuModeCard
        Card {
            id: gpuCard
            theme: pal
            shown: root.status.hasGpu === 1
            title: root.tr("Tryb grafiki")
            accent: look.sage
            readonly property string set: root.status.gpuSet || ""
            readonly property string active: root.status.gpuNow || ""
            readonly property bool pending: set !== "" && active !== "" && set !== active
            readonly property var mode: root.gpuModes.find(m => m.value === set)
            note: root.tr("teraz: %1", root.gpuLabel(active))
            ModeRow {
                theme: look
                modes: root.gpuModes
                current: root.gpuBusy ? root.gpuWanted : gpuCard.set
                busy: root.gpuBusy
                accent: gpuCard.layered ? look.ink : look.sage
                onPicked: (arg, label) => root.setGpu(arg)
            }
            Txt {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                readonly property string missed: root.status.gpuFail || ""
                // W warstwach zwykły opis aktywnego trybu odpada; zostają zapis, błędy i oczekiwanie na restart.
                visible: text !== "" && (!gpuCard.layered || root.gpuBusy || root.gpuFailed || gpuCard.pending || missed !== "")
                text: root.gpuBusy ? "… " + root.tr("Zapisuję: %1. To może potrwać do pół minuty.", root.gpuLabel(root.gpuWanted))
                    : root.gpuFailed ? "⚠ " + root.tr("Nie udało się zapisać trybu grafiki.")
                    : gpuCard.pending ? "✓ " + root.tr("Zapisano: %1. Zadziała po restarcie.", root.gpuLabel(gpuCard.set))
                    : missed ? "⚠ " + root.tr("Po restarcie nadal %1, firmware nie włączył %2.", root.gpuLabel(gpuCard.active), root.gpuLabel(missed))
                    : gpuCard.mode ? "✓ " + root.tr("Aktywny: %1", gpuCard.mode.label) + ", " + gpuCard.mode.hint : ""
                color: root.gpuBusy ? look.ink : root.gpuFailed || missed ? look.alert : gpuCard.pending ? look.warn : look.faint
                font.pixelSize: gpuCard.layered ? 13 : 11
            }
        }
    }

    // VPN
    Component {
        id: vpnCard
        Card {
            id: vpn
            theme: pal
            title: "VPN"
            readonly property bool on: !!root.status.vpn
            readonly property bool blocking: root.status.ks === 1 && !on
            shown: root.vpnTool || on || root.vpnList.length > 0
            accent: blocking ? look.alert : on ? look.sage : look.faint
            readonly property bool proton: root.vpnNow === root.protonName
            note: root.vpnRolling ? root.tr("zmiana IP…")
                : root.vpnBusy ? (on && !root.vpnPick ? root.tr("rozłączanie…") : root.tr("łączenie…"))
                : on ? root.status.vpn.replace("ProtonVPN ", "")
                : root.status.noVpnNet === 1 ? root.tr("ta sieć: bez VPN-a")
                : root.status.manualOff === 1 ? root.tr("wyłączony ręcznie") : root.tr("wyłączony")

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Txt {
                    visible: !vpn.layered
                    text: vpn.on ? "🛡" : "○"
                    color: vpn.on ? look.sage : look.faint
                    font.pixelSize: 22
                }
                Icon {
                    visible: vpn.layered
                    name: vpn.on ? "shield" : "shieldOff"
                    color: vpn.blocking ? look.alert : vpn.on ? look.sage : look.muted
                    size: 22
                }
                Column {
                    Layout.fillWidth: true
                    Txt {
                        text: !vpn.on ? root.tr("Bez VPN-a") : vpn.proton ? root.tr("Chroniony") : root.tr("Połączono")
                        face: vpn.layered ? look.display : ""
                        color: vpn.layered && vpn.on ? look.sage : look.ink
                        font.pixelSize: vpn.layered ? 18 : 15; font.weight: vpn.layered ? Font.DemiBold : Font.Medium
                    }
                    Txt {
                        visible: text !== ""
                        // W warstwach podtytuł podaje serwer albo stan zamiast opisu tunelu.
                        text: vpn.layered ? (root.vpnBusy || !vpn.on ? vpn.note
                                : vpn.proton ? root.protonName + " · " + root.status.vpn.replace("ProtonVPN ", "") : root.vpnNow)
                            : !root.vpnTool ? (vpn.on ? root.tr("ruch idzie szyfrowanym tunelem") : "")
                            : !vpn.on ? root.tr("wraca sam po zmianie sieci")
                            : vpn.proton ? root.tr("ruch idzie szyfrowanym tunelem") : root.tr("po zmianie sieci wraca Proton")
                        color: vpn.layered ? look.muted : look.faint
                        font.pixelSize: vpn.layered ? 13 : 11
                    }
                }
                // Nowe IP
                Rectangle {
                    visible: root.vpnTool && vpn.proton
                    implicitWidth: rollRow.implicitWidth + 22; implicitHeight: vpn.layered ? 30 : 30; radius: height / 2
                    color: vpn.layered ? (rollMouse.containsMouse && !root.vpnBusy ? look.tint(look.ink, 0.12) : "transparent")
                        : rollMouse.containsMouse && !root.vpnBusy ? look.tint(look.sage, 0.28) : look.track
                    border.width: vpn.layered ? 1 : 0
                    border.color: look.tint(look.ink, 0.45)
                    opacity: root.vpnBusy ? 0.55 : 1
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Row {
                        id: rollRow
                        anchors.centerIn: parent
                        spacing: 5
                        Icon { visible: vpn.layered; name: "refresh"; color: look.ink; size: 13; anchors.verticalCenter: parent.verticalCenter }
                        Txt {
                            text: (vpn.layered ? "" : "↻ ") + root.tr("Nowe IP")
                            color: look.ink; font.pixelSize: vpn.layered ? 13 : 12; font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        id: rollMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.vpnBusy
                        onClicked: root.rollVpn()
                    }
                }
            }
            // Lista wyboru VPN-a
            Repeater {
                model: root.vpnList
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: root.vpnNow === modelData
                    readonly property bool picking: root.vpnPick === modelData
                    Layout.fillWidth: true
                    implicitHeight: vpn.layered ? 31 : 30
                    radius: vpn.layered ? height / 2 : 10
                    color: vpn.layered ? (active ? look.tint(look.ink, 0.14) : "transparent")
                        : active ? look.tint(look.sage, 0.28) : look.track
                    border.width: vpn.layered ? 1 : 0
                    border.color: look.tint(look.ink, active ? 0.5 : 0.28)
                    opacity: root.vpnBusy && !picking ? 0.55 : 1
                    Behavior on color { ColorAnimation { duration: 200 } }
                    RowLayout {
                        anchors { fill: parent; leftMargin: vpn.layered ? 13 : 10; rightMargin: vpn.layered ? 13 : 10 }
                        spacing: 8
                        Txt { text: modelData; color: look.ink; font.pixelSize: vpn.layered ? 13 : 12; font.weight: active ? Font.DemiBold : Font.Normal; elide: Text.ElideRight; Layout.fillWidth: true }
                        Txt {
                            text: picking ? root.tr("łączenie…")
                                : active && pickMouse.containsMouse && !root.vpnBusy ? root.tr("rozłącz")
                                : active ? "✓ " + root.tr("połączono") : ""
                            color: active && !pickMouse.containsMouse ? look.sage : look.faint; font.pixelSize: vpn.layered ? 13 : 11
                        }
                    }
                    MouseArea {
                        id: pickMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.vpnBusy
                        onClicked: active ? root.toggleVpn(false) : root.pickVpn(modelData)
                    }
                }
            }
            Txt {
                Layout.fillWidth: true
                visible: root.vpnFailed !== ""
                wrapMode: Text.WordWrap
                text: "⚠ " + root.tr("Nie udało się połączyć z %1.", root.vpnFailed)
                color: look.alert; font.pixelSize: vpn.layered ? 13 : 11
            }
            // Ostrzeżenie o kill switchu
            Rectangle {
                Layout.fillWidth: true
                visible: root.status.ks === 1 && (root.cfg.vpnWarning || vpn.blocking)
                implicitHeight: ksText.implicitHeight + 14
                radius: 10
                color: look.tint(vpn.blocking ? look.alert : look.warn, 0.14)
                Txt {
                    id: ksText
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                    wrapMode: Text.WordWrap
                    font.pixelSize: vpn.layered ? 13 : 12
                    color: vpn.blocking ? look.alert : look.warn
                    text: "⚠ " + (vpn.blocking
                        ? root.tr("Kill switch blokuje internet. Włącz VPN, żeby odzyskać połączenie.")
                        : root.tr("Kill switch aktywny: jeśli VPN się zerwie, internet zostanie zablokowany."))
                }
            }
        }
    }

    // System
    Component {
        id: systemCard
        Card {
            theme: pal
            title: root.tr("System")
            accent: look.teal
            note: root.cfg.showHost ? root.txt(osHost) : ""
            leadTitle: true
            Line { theme: look; name: root.tr("System"); value: root.txt(osName) }
            Line { theme: look; name: root.tr("Jądro"); value: root.txt(osKernel) }
            Line { theme: look; name: "Plasma"; value: root.txt(osPlasma) }
            Line { theme: look; name: root.tr("Działa od"); value: root.ok(osUptime) ? root.span(Number(osUptime.value) * 1000) : "—" }
            clickable: root.cfg.clickActions
            onTapped: root.run("kinfocenter")
        }
    }

    // Procesy: programy zajmujące najwięcej pamięci
    Component {
        id: procsCard
        Card {
            id: procs
            theme: pal
            title: root.tr("Najwięcej pamięci")
            leadTitle: true
            accent: look.dusk
            readonly property var list: (root.status.top || []).slice(0, root.cfg.procCount)
            readonly property real total: root.num(ramTotal) || 1
            shown: list.length > 0
            Repeater {
                model: procs.list.length
                delegate: MeterRow {
                    required property int index
                    readonly property var item: procs.list[index] || ({ name: "", mb: 0 })
                    theme: look
                    name: item.name
                    detail: root.size(item.mb * 1048576)
                    value: 100 * item.mb * 1048576 / procs.total
                    color: look.dusk
                    nameSize: 12
                    barHeight: 4
                }
            }
            clickable: root.cfg.clickActions
            onTapped: root.run("plasma-systemmonitor")
        }
    }

    // Notatka
    Component {
        id: notesCard
        Card {
            theme: pal
            shown: root.cfg.notes !== ""
            title: root.cfg.notesTitle || root.tr("Notatka")
            leadTitle: true
            accent: look.gold
            Txt {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.cfg.notes
                color: look.ink; font.pixelSize: 13; lineHeight: 1.15
            }
        }
    }

    // Własny kafelek
    Component {
        id: customCard
        Card {
            theme: pal
            shown: root.cfg.customCommand !== ""
            title: root.cfg.customTitle || root.tr("Własny")
            leadTitle: true
            accent: look.clay
            Txt {
                Layout.fillWidth: true
                wrapMode: Text.WrapAnywhere
                text: root.customText || "…"
                color: look.ink; font.pixelSize: 12; font.family: "monospace"
            }
        }
    }

    fullRepresentation: Item {
        id: rep
        readonly property real user: Math.max(0.5, root.cfg.scale / 100)
        readonly property int gap: root.cfg.spacing
        // Łączna wysokość wszystkich kafelków, zaokrąglona, żeby układ nie drgał przy drobnych zmianach.
        readonly property real total: {
            var h = 0;
            for (var i = 0; i < columns.count; i++) {
                var c = columns.itemAt(i);
                if (c) h += c.implicitHeight + gap;
            }
            return Math.ceil(h / 24) * 24;
        }
        // Dopasowanie do miejsca na ekranie: dla każdej liczby kolumn liczy największą skalę, przy której
        // kolumny (co najmniej 300 px) mieszczą się na szerokość, a kafelki na wysokość, i bierze najlepszą.
        // Skala z ustawień jest górną granicą; przy remisie wygrywa więcej kolumn, więc szeroki widżet
        // rozkłada kafelki obok siebie, a na małym ekranie całość się zmniejsza zamiast wystawać.
        // Skala zmienia szerokość kafelków, a więc łamanie tekstu i ich wysokość, od której sama zależy.
        // Dlatego układ ustawia się krokami, nie wiązaniem: zmniejsza się od razu, a rośnie dopiero
        // przy wyraźnym zysku, więc nie skacze między dwoma stanami.
        property int cols: 1
        property real fitted: user
        function relayout() {
            var count = Math.max(1, root.cards.length), best = { cols: 1, scale: 0 };
            var from = root.cfg.columns > 0 ? Math.min(root.cfg.columns, count) : 1;
            var to = root.cfg.columns > 0 ? from : Math.min(count, 8);
            for (var c = from; c <= to; c++) {
                // Liczba kolumn, przy której któraś zostałaby pusta, nic nie daje.
                if (root.cfg.columns <= 0 && Math.ceil(count / Math.ceil(count / c)) !== c) continue;
                var byWidth = width > 0 ? width / (c * 300 + (c - 1) * gap) : user;
                var byHeight = root.cfg.fitHeight && height > 0 && total > 0 ? height * c / total : user;
                var s = Math.min(user, byWidth, byHeight);
                if (s >= best.scale - 0.001) best = { cols: c, scale: s };
            }
            var next = Math.max(0.2, best.scale);
            if (best.cols !== cols) { cols = best.cols; fitted = next; }
            else if (next < fitted - 0.005 || next > fitted * 1.06 || next >= user) fitted = next;
        }
        Timer { id: settle; interval: 120; onTriggered: rep.relayout() }
        onWidthChanged: settle.restart()
        onHeightChanged: settle.restart()
        onTotalChanged: settle.restart()
        onUserChanged: settle.restart()
        Connections {
            target: root
            function onCardsChanged() { settle.restart(); }
        }
        Connections {
            target: root.cfg
            function onColumnsChanged() { settle.restart(); }
            function onFitHeightChanged() { settle.restart(); }
            function onSpacingChanged() { settle.restart(); }
        }
        Component.onCompleted: settle.restart()
        readonly property int perCol: Math.ceil(root.cards.length / cols)
        // Kolumny nie są równej wysokości, więc ostatnia poprawka pilnuje, żeby nic nie wyszło poza dół.
        readonly property real fit: root.cfg.fitHeight && height > 0 && grid.implicitHeight * fitted > height ? height / (grid.implicitHeight * fitted) : 1
        Layout.preferredWidth: (330 * Math.max(1, root.cfg.columns) + gap * Math.max(0, root.cfg.columns - 1)) * user
        Layout.minimumWidth: 160
        Layout.preferredHeight: grid.implicitHeight * user

        Row {
            id: grid
            readonly property bool leftSide: root.cfg.align === "left"
            width: rep.width / rep.fitted
            x: leftSide ? 0 : rep.width - width
            spacing: rep.gap
            scale: rep.fitted * rep.fit
            transformOrigin: leftSide ? Item.TopLeft : Item.TopRight
            Repeater {
                id: columns
                model: rep.cols
                delegate: Column {
                    id: column
                    required property int index
                    width: (grid.width - rep.gap * (rep.cols - 1)) / rep.cols
                    // Warstwy stykają się ze sobą; nad zaokrąglonym wierzchem stosu zostaje odstęp od krawędzi.
                    spacing: pal.strata ? 0 : rep.gap
                    topPadding: pal.strata ? 12 : 0
                    Repeater {
                        model: root.cards.slice(column.index * rep.perCol, (column.index + 1) * rep.perCol)
                        delegate: Loader {
                            required property string modelData
                            width: column.width
                            sourceComponent: root.cardOf(modelData)
                            // Kafelek bez danych znika z kolumny razem z odstępem.
                            visible: !!item && item.shown
                        }
                    }
                }
            }
        }
    }
}
