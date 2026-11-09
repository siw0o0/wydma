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

    Timer {
        interval: 1000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: {
            root.now = new Date();
            root.down = root.down.concat([root.num(netDown)]).slice(-40);
            root.up = root.up.concat([root.num(netUp)]).slice(-40);
        }
    }

    // VPN. Ze skryptem ~/.local/bin/protonvpn-auto steruje on Protonem i pilnuje sieci bez VPN-a;
    // bez niego przełącznik i lista łączą profile NetworkManagera wprost.
    property bool vpnBusy: false
    readonly property bool vpnTool: status.hasVpn === 1
    readonly property string vpnCmd: "\"$HOME/.local/bin/protonvpn-auto\" "
    readonly property string protonName: "Proton VPN"
    readonly property string vpnNow: !status.vpn ? "" : vpnTool && status.vpn.indexOf("ProtonVPN") === 0 ? protonName : status.vpn
    readonly property var vpnList: (vpnTool ? [protonName] : []).concat(status.vpns || [])
    property string vpnPick
    property string vpnFailed
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
    property bool gpuBusy: false
    property bool gpuFailed: false
    readonly property var gpuModes: [
        { arg: "hybrid", value: "hybrid", label: "Hybrid", hint: tr("ekran na Intelu, NVIDIA włącza się w razie potrzeby") },
        { arg: "igpu", value: "igpu", label: "iGPU", hint: tr("tylko Intel, monitor zewnętrzny może nie działać") },
        { arg: "dgpu", value: "dgpu", label: "dGPU", hint: tr("wszystko na NVIDII, G-Sync, większy pobór prądu") }
    ]
    function gpuLabel(v) { var m = gpuModes.find(x => x.value === v); return m ? m.label : "—"; }
    function setGpu(arg) {
        gpuBusy = true;
        gpuFailed = false;
        gpuExec.connectSource("sudo -n /usr/local/sbin/gpu-mode " + arg);
    }
    P5Support.DataSource {
        id: gpuExec
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            root.gpuBusy = false;
            root.gpuFailed = data["exit code"] !== 0;
            root.refresh(false);
        }
    }

    // Limity Claude, zasilanie, VPN, słuchawki i procesy z jednego skryptu: co 10 s lekki odczyt,
    // raz na minutę pełny (z listą profili VPN).
    readonly property string statusCmd: (cfg.usageFile ? "WYDMA_USAGE=" + q(cfg.usageFile) + " " : "")
        + "sh " + q(Qt.resolvedUrl("../code/status.sh").toString().replace("file://", ""))
    function refresh(full) { exec.connectSource(statusCmd + (full ? " full" : "") + (has("procs") ? " procs" : "")); }
    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            try {
                var next = JSON.parse(data["stdout"]);
                // Lista VPN-ów przychodzi tylko w pełnym odczycie; między nimi zostaje poprzednia.
                if (next.vpns === null) next.vpns = root.status.vpns || [];
                root.status = next;
            } catch (e) {}
            disconnectSource(source);
        }
    }
    property int ticks: 0
    Timer {
        interval: 10000; repeat: true; running: true; triggeredOnStart: true
        onTriggered: root.refresh(root.ticks++ % 6 === 0)
    }

    // Plan co minutę: polecenie z ustawień albo program ~/.config/wydma/plan. Podaje jedną linię JSON
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
        interval: 60000; repeat: true; running: root.has("plan"); triggeredOnStart: true
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
        property string name
        property string value
        Layout.fillWidth: true
        spacing: 10
        Text { text: parent.name; color: pal.muted; font.pixelSize: 12 }
        Text { text: parent.value; color: pal.ink; font.pixelSize: 12; font.weight: Font.Medium; elide: Text.ElideRight; horizontalAlignment: Text.AlignRight; Layout.fillWidth: true }
    }

    // Zegar
    Component {
        id: clockCard
        Item {
            property bool shown: true
            readonly property bool leftSide: root.cfg.align === "left"
            implicitHeight: clockCol.implicitHeight + 8
            height: implicitHeight
            ColumnLayout {
                id: clockCol
                x: parent.leftSide ? 6 : parent.width - width - 6
                spacing: -4
                Text {
                    Layout.alignment: parent.parent.leftSide ? Qt.AlignLeft : Qt.AlignRight
                    text: Qt.formatTime(root.now, root.cfg.clock12 ? (root.cfg.seconds ? "h:mm:ss AP" : "h:mm AP") : (root.cfg.seconds ? "HH:mm:ss" : "HH:mm"))
                    color: root.cfg.darkClock ? "#2a2018" : "white"
                    font.pixelSize: root.cfg.clockSize; font.weight: Font.Light; font.features: { "tnum": 1 }
                    style: Text.Raised; styleColor: root.cfg.darkClock ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0.25, 0.15, 0.05, 0.25)
                }
                Text {
                    Layout.alignment: parent.parent.leftSide ? Qt.AlignLeft : Qt.AlignRight
                    visible: root.cfg.showDate
                    text: root.cfg.dateFormat === "iso" ? Qt.formatDate(root.now, "yyyy-MM-dd")
                        : root.cfg.dateFormat === "short" ? root.now.toLocaleDateString(root.loc, "ddd, d MMM")
                        : root.now.toLocaleDateString(root.loc, "dddd, d MMMM")
                    color: root.cfg.darkClock ? "#2a2018" : "white"
                    font.pixelSize: Math.max(11, root.cfg.clockSize / 4); font.weight: Font.Medium
                    style: Text.Raised; styleColor: root.cfg.darkClock ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0.25, 0.15, 0.05, 0.3)
                }
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
            accent: pal.teal
            readonly property var list: root.plan && root.plan.zajecia ? root.plan.zajecia.filter(z => Date.parse(z.koniec) > root.now) : []
            readonly property var cur: list.length ? list[0] : null
            readonly property real startMs: cur ? Date.parse(cur.start) : 0
            readonly property real endMs: cur ? Date.parse(cur.koniec) : 0
            readonly property bool live: cur !== null && startMs <= root.now
            note: !cur ? "" : live ? root.tr("trwa, jeszcze %1", root.span(endMs - root.now))
                : startMs - root.now < 12 * 3600000 ? root.tr("za %1", root.span(startMs - root.now))
                : root.dayName(cur.start)

            // Kliknięcie w kafelek otwiera aplikację z planem.
            clickable: true
            onTapped: root.openPlan()

            RowLayout {
                Layout.fillWidth: true
                visible: classCard.cur !== null
                spacing: 12
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    visible: !!classCard.cur && !!classCard.cur.forma
                    implicitWidth: 34; implicitHeight: 34; radius: 10
                    color: pal.tint(pal.teal, 0.16)
                    Text { anchors.centerIn: parent; text: classCard.cur ? classCard.cur.forma || "" : ""; color: pal.teal; font.pixelSize: 15; font.weight: Font.DemiBold }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: classCard.cur ? classCard.cur.przedmiot : ""
                        color: pal.ink; font.pixelSize: 15; font.weight: Font.Medium
                        wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: classCard.cur ? root.dayName(classCard.cur.start) + " " + root.hm(classCard.cur.start) + "–" + root.hm(classCard.cur.koniec)
                            + (classCard.cur.forma ? " · " + root.formName(classCard.cur.forma) : "") : ""
                        color: pal.muted; font.pixelSize: 12
                    }
                    Text {
                        Layout.fillWidth: true
                        readonly property var where: classCard.cur ? [classCard.cur.sala ? root.tr("sala %1", classCard.cur.sala) : "", classCard.cur.budynek, classCard.cur.uwaga].filter(p => p) : []
                        visible: where.length > 0
                        text: where.join(" · ")
                        color: pal.faint; font.pixelSize: 12; elide: Text.ElideRight
                    }
                }
            }
            Bar {
                Layout.fillWidth: true
                visible: classCard.live
                implicitHeight: 6
                value: classCard.live ? 100 * (root.now - classCard.startMs) / (classCard.endMs - classCard.startMs) : 0
                color: pal.teal; track: pal.track
            }
            // Kolejne pozycje
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: pal.track; visible: classCard.list.length > 1 && root.cfg.planCount > 0 }
            Repeater {
                model: Math.min(root.cfg.planCount, Math.max(0, classCard.list.length - 1))
                delegate: RowLayout {
                    required property int index
                    readonly property var cls: classCard.list[index + 1] || null
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: cls ? root.dayName(cls.start) + " " + root.hm(cls.start) : ""
                        color: pal.muted; font.pixelSize: 12; font.features: { "tnum": 1 }
                        Layout.preferredWidth: 88
                    }
                    Text { text: cls ? cls.przedmiot + (cls.forma ? " (" + cls.forma + ")" : "") : ""; color: pal.ink; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { text: cls ? cls.sala || "" : ""; color: pal.faint; font.pixelSize: 12 }
                }
            }
            Text {
                visible: !classCard.cur
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.tr("Nic zaplanowanego.")
                color: pal.muted; font.pixelSize: 12
            }
            Text {
                visible: !!root.plan && !!root.plan.pobrano && root.now - Date.parse(root.plan.pobrano) > 3 * 86400000
                Layout.fillWidth: true
                text: visible ? root.tr("plan z %1, do odświeżenia", new Date(Date.parse(root.plan.pobrano)).toLocaleDateString(root.loc, "d.MM")) : ""
                color: pal.warn; font.pixelSize: 11
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
            accent: pal.clay
            readonly property var usage: root.status.usage || null
            note: usage ? root.tr("odczyt %1 temu", root.span(root.now - usage.at)) : ""
            Repeater {
                model: claude.usage ? claude.usage.limits.length : 0
                delegate: MeterRow {
                    required property int index
                    readonly property var lim: claude.usage ? claude.usage.limits[index] : null
                    theme: pal
                    name: lim ? root.limitName(lim.kind) : ""
                    detail: lim && lim.resetsAt ? root.tr("reset za %1", root.span(Date.parse(lim.resetsAt) - root.now)) : ""
                    value: lim ? lim.percent : 0
                    color: pal.clay
                    nameSize: 14
                    barHeight: 8
                }
            }
            Text {
                visible: !claude.usage
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.tr("Brak odczytu. Pojawi się po pierwszej odpowiedzi Claude (potrzebna wtyczka Claudbar).")
                color: pal.muted; font.pixelSize: 12
            }
        }
    }

    // CPU i GPU
    Component {
        id: cpuCard
        Card {
            theme: pal
            title: root.tr("Procesor i grafika")
            accent: pal.sky
            note: root.gpuLive ? root.gpuTitle : (root.gpuTitle ? root.gpuTitle + ", " : "") + root.tr("odczyt na zasilaczu")
            RowLayout {
                Layout.fillWidth: true
                Gauge { theme: pal; name: "CPU"; value: root.num(cpu); temp: root.num(cpuTemp); tempText: root.temp(cpuTemp); tempWarn: root.cfg.tempWarn; tempAlert: root.cfg.tempAlert; color: pal.sky }
                Gauge { theme: pal; name: "GPU"; value: root.gpuNum(gpuUse); temp: root.gpuNum(gpuTemp); tempText: root.gpuLive ? root.temp(gpuTemp) : "—"; tempWarn: root.cfg.tempWarn; tempAlert: root.cfg.tempAlert; color: pal.sage }
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
            accent: pal.dusk
            MeterRow { theme: pal; name: "RAM"; value: root.num(ram); detail: root.gib(root.num(ramUsed)) + " / " + root.gib(root.num(ramTotal)) + " GiB"; color: pal.dusk }
            MeterRow {
                theme: pal; visible: root.cfg.showSwap && root.num(swapTotal) > 0
                name: root.tr("Wymiana"); value: root.num(swap); detail: root.gib(root.num(swapUsed)) + " / " + root.gib(root.num(swapTotal)) + " GiB"; color: pal.teal
            }
            MeterRow {
                theme: pal; visible: root.cfg.showVram
                name: "VRAM"; value: root.gpuNum(vramTotal) > 0 ? 100 * root.gpuNum(vramUsed) / root.gpuNum(vramTotal) : 0
                detail: root.gpuLive ? root.txt(vramUsed) + " / " + root.txt(vramTotal) : "—"; color: pal.sage
            }
            MeterRow { theme: pal; name: root.tr("Dysk"); value: root.num(disk); detail: root.tr("wolne %1", root.txt(diskFree)); color: pal.gold }
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
            accent: pal.sky
            note: root.cfg.netIface && root.cfg.netIface !== "all" ? root.cfg.netIface : ""
            RowLayout {
                Layout.fillWidth: true
                Text { text: "↓ " + root.speed(root.num(netDown)); color: pal.sky; font.pixelSize: 15; font.weight: Font.Medium; font.features: { "tnum": 1 } }
                Item { Layout.fillWidth: true }
                Text { text: "↑ " + root.speed(root.num(netUp)); color: pal.clay; font.pixelSize: 15; font.weight: Font.Medium; font.features: { "tnum": 1 } }
            }
            Spark { Layout.fillWidth: true; visible: root.cfg.netGraph; series: [root.down, root.up]; colors: [pal.sky, pal.clay] }
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
            accent: pal.gold
            readonly property bool hasBat: root.status.bat !== undefined && root.status.bat !== null
            readonly property real bat: root.status.bat || 0
            readonly property bool ac: root.status.ac === 1
            readonly property bool hasHeadset: root.status.headsetPct !== undefined && root.status.headsetPct !== null
            shown: hasBat || hasHeadset || root.profileName(root.status.profile) !== ""
            note: root.profileName(root.status.profile)
            RowLayout {
                Layout.fillWidth: true
                visible: power.hasBat
                Text {
                    text: (power.ac ? "🔌 " + root.tr("Zasilacz") : "🔋 " + root.tr("Bateria"))
                        + (!power.ac && root.status.watts > 0.5 ? " · " + root.dec(root.status.watts, 1) + " W" : "")
                    color: pal.ink; font.pixelSize: 13; font.weight: Font.Medium
                }
                Item { Layout.fillWidth: true }
                Text { text: root.pct(power.bat); color: power.bat <= 15 ? pal.alert : power.bat <= 30 ? pal.warn : pal.ink; font.pixelSize: 13; font.weight: Font.DemiBold }
            }
            Bar { Layout.fillWidth: true; visible: power.hasBat; implicitHeight: 6; value: power.bat; color: power.bat <= 15 ? pal.alert : power.bat <= 30 ? pal.warn : pal.sage; track: pal.track }
            Text {
                visible: !power.hasBat && !power.hasHeadset
                text: "🔌 " + root.tr("Zasilanie sieciowe")
                color: pal.ink; font.pixelSize: 13; font.weight: Font.Medium
            }
            // Tryb ładowania
            ModeRow {
                theme: pal
                visible: root.status.hasCharge === 1
                modes: root.chargeModes
                current: root.status.charge || ""
                busy: root.chargeBusy
                accent: pal.gold
                onPicked: (arg, label) => root.setCharge(arg, label)
            }
            Text {
                Layout.fillWidth: true
                visible: root.status.hasCharge === 1
                wrapMode: Text.WordWrap
                readonly property var mode: root.chargeModes.find(m => m.value === root.status.charge)
                text: root.chargeFailed ? "⚠ " + root.tr("Nie udało się zmienić trybu ładowania.")
                    : root.chargeDone ? "✓ " + root.tr("Włączono: %1", root.chargeDone)
                    : mode ? mode.hint : ""
                color: root.chargeFailed ? pal.alert : root.chargeDone ? pal.sage : pal.faint
                font.pixelSize: 11
            }
            RowLayout {
                Layout.fillWidth: true
                visible: power.hasHeadset
                Text { text: "🎧 " + (root.status.headset || root.tr("Słuchawki")); color: pal.ink; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                Text {
                    readonly property real charge: root.status.headsetPct || 0
                    text: root.pct(charge); color: charge <= 15 ? pal.alert : charge <= 30 ? pal.warn : pal.ink; font.pixelSize: 13; font.weight: Font.DemiBold
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
            accent: pal.sage
            readonly property string set: root.status.gpuSet || ""
            readonly property string active: root.status.gpuNow || ""
            readonly property bool pending: set !== "" && active !== "" && set !== active
            readonly property var mode: root.gpuModes.find(m => m.value === set)
            note: root.tr("teraz: %1", root.gpuLabel(active))
            ModeRow {
                theme: pal
                modes: root.gpuModes
                current: gpuCard.set
                busy: root.gpuBusy
                accent: pal.sage
                onPicked: (arg, label) => root.setGpu(arg)
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                readonly property string missed: root.status.gpuFail || ""
                text: root.gpuFailed ? "⚠ " + root.tr("Nie udało się zapisać trybu grafiki.")
                    : gpuCard.pending ? "✓ " + root.tr("Zapisano: %1. Zadziała po restarcie.", root.gpuLabel(gpuCard.set))
                    : missed ? "⚠ " + root.tr("Po restarcie nadal %1, firmware nie włączył %2.", root.gpuLabel(gpuCard.active), root.gpuLabel(missed))
                    : gpuCard.mode ? "✓ " + root.tr("Aktywny: %1", gpuCard.mode.label) + ", " + gpuCard.mode.hint : ""
                color: root.gpuFailed || missed ? pal.alert : gpuCard.pending ? pal.warn : pal.faint
                font.pixelSize: 11
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
            accent: blocking ? pal.alert : on ? pal.sage : pal.faint
            readonly property bool proton: root.vpnNow === root.protonName
            note: root.vpnBusy ? (on && !root.vpnPick ? root.tr("rozłączanie…") : root.tr("łączenie…"))
                : on ? root.status.vpn.replace("ProtonVPN ", "")
                : root.status.noVpnNet === 1 ? root.tr("ta sieć: bez VPN-a")
                : root.status.manualOff === 1 ? root.tr("wyłączony ręcznie") : root.tr("wyłączony")

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: vpn.on ? "🛡" : "○"
                    color: vpn.on ? pal.sage : pal.faint
                    font.pixelSize: 22
                }
                Column {
                    Layout.fillWidth: true
                    Text { text: !vpn.on ? root.tr("Bez VPN-a") : vpn.proton ? root.tr("Chroniony") : root.tr("Połączono"); color: pal.ink; font.pixelSize: 15; font.weight: Font.Medium }
                    Text {
                        visible: text !== ""
                        text: !root.vpnTool ? (vpn.on ? root.tr("ruch idzie szyfrowanym tunelem") : "")
                            : !vpn.on ? root.tr("wraca sam po zmianie sieci")
                            : vpn.proton ? root.tr("ruch idzie szyfrowanym tunelem") : root.tr("po zmianie sieci wraca Proton")
                        color: pal.faint; font.pixelSize: 11
                    }
                }
                // Przełącznik
                Rectangle {
                    visible: root.vpnTool || vpn.on || root.vpnList.length > 0
                    width: 52; height: 30; radius: 15
                    color: vpn.on ? pal.sage : pal.track
                    opacity: root.vpnBusy ? 0.55 : 1
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        y: 3; x: vpn.on ? parent.width - width - 3 : 3
                        color: "white"
                        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.vpnBusy
                        onClicked: root.toggleVpn(!vpn.on)
                    }
                }
            }
            // Lista wyboru VPN-a
            Repeater {
                model: root.vpnList.length > 1 || !root.vpnTool ? root.vpnList : []
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool active: root.vpnNow === modelData
                    readonly property bool picking: root.vpnPick === modelData
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: 10
                    color: active ? pal.tint(pal.sage, 0.28) : pal.track
                    opacity: root.vpnBusy && !picking ? 0.55 : 1
                    Behavior on color { ColorAnimation { duration: 200 } }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 8
                        Text { text: modelData; color: pal.ink; font.pixelSize: 12; font.weight: active ? Font.DemiBold : Font.Normal; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: picking ? root.tr("łączenie…") : active ? "✓ " + root.tr("połączono") : ""; color: active ? pal.sage : pal.faint; font.pixelSize: 11 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.vpnBusy && !active
                        onClicked: root.pickVpn(modelData)
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: root.vpnFailed !== ""
                wrapMode: Text.WordWrap
                text: "⚠ " + root.tr("Nie udało się połączyć z %1.", root.vpnFailed)
                color: pal.alert; font.pixelSize: 11
            }
            // Ostrzeżenie o kill switchu
            Rectangle {
                Layout.fillWidth: true
                visible: root.status.ks === 1 && (root.cfg.vpnWarning || vpn.blocking)
                implicitHeight: ksText.implicitHeight + 14
                radius: 10
                color: pal.tint(vpn.blocking ? pal.alert : pal.warn, 0.14)
                Text {
                    id: ksText
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                    color: vpn.blocking ? pal.alert : pal.warn
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
            accent: pal.teal
            note: root.cfg.showHost ? root.txt(osHost) : ""
            Line { name: root.tr("System"); value: root.txt(osName) }
            Line { name: root.tr("Jądro"); value: root.txt(osKernel) }
            Line { name: "Plasma"; value: root.txt(osPlasma) }
            Line { name: root.tr("Działa od"); value: root.ok(osUptime) ? root.span(Number(osUptime.value) * 1000) : "—" }
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
            accent: pal.dusk
            readonly property var list: (root.status.top || []).slice(0, root.cfg.procCount)
            readonly property real total: root.num(ramTotal) || 1
            shown: list.length > 0
            Repeater {
                model: procs.list.length
                delegate: MeterRow {
                    required property int index
                    readonly property var item: procs.list[index] || ({ name: "", mb: 0 })
                    theme: pal
                    name: item.name
                    detail: root.size(item.mb * 1048576)
                    value: 100 * item.mb * 1048576 / procs.total
                    color: pal.dusk
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
            accent: pal.gold
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: root.cfg.notes
                color: pal.ink; font.pixelSize: 13; lineHeight: 1.15
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
            accent: pal.clay
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WrapAnywhere
                text: root.customText || "…"
                color: pal.ink; font.pixelSize: 12; font.family: "monospace"
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
        readonly property var layout: {
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
            return { cols: best.cols, scale: Math.max(0.2, best.scale) };
        }
        readonly property int cols: layout.cols
        readonly property int perCol: Math.ceil(root.cards.length / cols)
        // Kolumny nie są równej wysokości, więc ostatnia poprawka pilnuje, żeby nic nie wyszło poza dół.
        readonly property real fit: root.cfg.fitHeight && height > 0 && grid.implicitHeight * layout.scale > height ? height / (grid.implicitHeight * layout.scale) : 1
        Layout.preferredWidth: (330 * Math.max(1, root.cfg.columns) + gap * Math.max(0, root.cfg.columns - 1)) * user
        Layout.minimumWidth: 160
        Layout.preferredHeight: grid.implicitHeight * user

        Row {
            id: grid
            readonly property bool leftSide: root.cfg.align === "left"
            width: rep.width / rep.layout.scale
            x: leftSide ? 0 : rep.width - width
            spacing: rep.gap
            scale: rep.layout.scale * rep.fit
            transformOrigin: leftSide ? Item.TopLeft : Item.TopRight
            Repeater {
                id: columns
                model: rep.cols
                delegate: Column {
                    id: column
                    required property int index
                    width: (grid.width - rep.gap * (rep.cols - 1)) / rep.cols
                    spacing: rep.gap
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
