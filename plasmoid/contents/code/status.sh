#!/bin/sh
# Jedna linia JSON dla widżetu: limity Claude, zasilanie, VPN, słuchawki.
# Wołany co 10 s, więc bez ciężkich narzędzi: profil zasilania z D-Bus, jedno wywołanie nmcli
# i jedno upower. Argumenty: "full" dodaje listę profili VPN (zmienia się rzadko), "procs"
# programy zajmujące najwięcej pamięci. WYDMA_USAGE wskazuje inny plik z limitami Claude.
# Liczby z kropką, niezależnie od języka systemu.
export LC_NUMERIC=C
full=0; procs=0
for a in "$@"; do case "$a" in full) full=1 ;; procs) procs=1 ;; esac; done

# Limity zapisuje mod Claudbar; starszy plik zostaje jako zapas.
usage=$(cat "${WYDMA_USAGE:-$HOME/.cache/claudbar/usage.json}" 2>/dev/null || cat "$HOME/.cache/claude-usage.json" 2>/dev/null)
# Plik musi być jednym obiektem JSON, inaczej zepsułby całą linię.
case "$usage" in "{"*"}") ;; *) usage="" ;; esac
[ -n "$usage" ] || usage=null

profile=$(busctl get-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles \
  org.freedesktop.UPower.PowerProfiles ActiveProfile 2>/dev/null | sed -n 's/^s "\(.*\)"$/\1/p')
[ -n "$profile" ] || profile=$(powerprofilesctl get 2>/dev/null)

active=$(nmcli -t -f TYPE,NAME con show --active 2>/dev/null)
# Nazwa trafia do JSON-a, więc cudzysłów i ukośnik dostają ukośnik.
vpn=$(echo "$active" | sed -n -E 's/^(wireguard|vpn)://p' | head -1 | sed 's/\\:/:/g; s/\\/\\\\/g; s/"/\\"/g')
# Kill switch Protona: interfejs pvpn-killswitch. Bez tunelu oznacza blokadę internetu.
ks=$(echo "$active" | grep -q '^dummy:pvpn-killswitch' && echo 1 || echo 0)
off=$( [ -f "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/protonvpn-manual-off" ] && echo 1 || echo 0)
# Własne ustawienia leżą w ~/.config/wydma: novpn (sieci Wi-Fi bez VPN-a, jedna w wierszu)
# i gpu (identyfikator karty w czujnikach systemu, np. gpu/gpu1).
conf="${XDG_CONFIG_HOME:-$HOME/.config}/wydma"
# Profil Wi-Fi nosi nazwę sieci.
wifi=$(echo "$active" | sed -n 's/^802-11-wireless://p' | head -1 | tr 'A-Z' 'a-z')
novpn=0
[ -n "$wifi" ] && grep -v '^#' "$conf/novpn" 2>/dev/null | tr 'A-Z' 'a-z' | grep -qxF -- "$wifi" && novpn=1
gpu=$(grep -m1 -E '^gpu/[A-Za-z0-9_]+$' "$conf/gpu" 2>/dev/null)

# Przełączniki pokazują się tylko tam, gdzie są ich skrypty (katalog helpers w repozytorium).
hasvpn=$( [ -x "$HOME/.local/bin/protonvpn-auto" ] && echo 1 || echo 0)

# Lista wyboru: profile VPN z NetworkManagera. Ze skryptem protonvpn-auto bez profili Protona,
# bo nim steruje skrypt; bez niego wszystkie, a widżet łączy je przez nmcli.
vpns=null
if [ "$full" = 1 ]; then
  skip='^$'; [ "$hasvpn" = 1 ] && skip='^(ProtonVPN|pvpn)'
  vpns="[$(nmcli -t -f NAME,TYPE con show 2>/dev/null | sed -n -E 's/:(vpn|wireguard)$//p' | grep -vE "$skip" | sed 's/\\:/:/g; s/\\/\\\\/g; s/"/\\"/g' | awk 'NR>1{printf ","}{printf "\"%s\"",$0}')]"
fi

# Bateria komputera (nie myszy czy słuchawek) i zasilacz, pod dowolną nazwą.
batdir=""; ac=null
for d in /sys/class/power_supply/*; do
  case "$(cat "$d/type" 2>/dev/null)" in
    Battery) [ -z "$batdir" ] && [ "$(cat "$d/scope" 2>/dev/null)" != Device ] && batdir=$d ;;
    Mains) [ "$ac" = 1 ] || ac=$(cat "$d/online" 2>/dev/null || echo null) ;;
  esac
done
bat=null; charge=""; watts=null; batstate=""
if [ -n "$batdir" ]; then
  bat=$(cat "$batdir/capacity" 2>/dev/null || echo null)
  batstate=$(cat "$batdir/status" 2>/dev/null)
  # Aktywny tryb ładowania jest w nawiasach: Fast [Standard] Long_Life.
  charge=$(sed -n 's/.*\[\(.*\)\].*/\1/p' "$batdir/charge_types" 2>/dev/null)
  # Pobór mocy w watach: power_now (µW) albo prąd razy napięcie.
  if [ -r "$batdir/power_now" ]; then
    watts=$(awk '{printf "%.1f", $1/1000000}' "$batdir/power_now")
  elif [ -r "$batdir/current_now" ] && [ -r "$batdir/voltage_now" ]; then
    watts=$(awk 'NR==1{c=$1} NR==2{printf "%.1f", c*$1/1000000000000}' "$batdir/current_now" "$batdir/voltage_now")
  fi
fi
# Komputer bez baterii i bez wpisu zasilacza działa z sieci.
[ "$ac" = null ] && [ -z "$batdir" ] && ac=1
[ "$ac" = null ] && ac=0

hascharge=$( [ -x /usr/local/sbin/battery-mode ] && [ -n "$charge" ] && echo 1 || echo 0)
hasgpu=$( [ -x /usr/local/sbin/gpu-mode ] && [ -d /sys/devices/platform/legion ] && echo 1 || echo 0)

# Programy zajmujące najwięcej pamięci, zsumowane po nazwie (przeglądarka to wiele procesów).
top=null
if [ "$procs" = 1 ]; then
  top="[$(ps -eo rss=,comm= 2>/dev/null | awk '{m[$2]+=$1} END {for (k in m) printf "%d %s\n", m[k], k}' | sort -rn | head -5 |
    awk '{name=$2; gsub(/["\\]/, "", name); printf("%s{\"name\":\"%s\",\"mb\":%d}", (NR > 1 ? "," : ""), name, $1 / 1024)}')]"
fi

# Tryb grafiki zapisany w firmware (legion_laptop) i faktycznie aktywny po starcie.
legion=/sys/devices/platform/legion
gpuset=""; gpunow=""; gpufail=""
if [ "$hasgpu" = 1 ]; then
  case "$(cat $legion/gsync 2>/dev/null):$(cat $legion/igpumode 2>/dev/null)" in
    0:*) gpuset=dgpu ;;
    1:1) gpuset=igpu ;;
    1:*) gpuset=hybrid ;;
  esac
  gpunow=igpu
  if [ -e /sys/bus/pci/devices/0000:01:00.0 ]; then
    gpunow=hybrid
    # Wewnętrzny ekran podłączony do NVIDII oznacza tryb dGPU.
    for c in /sys/class/drm/card*-eDP-*; do
      [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue
      card=${c##*/}; card=${card%%-*}
      [ "$(cat "/sys/class/drm/$card/device/vendor" 2>/dev/null)" = 0x10de ] && gpunow=dgpu
    done
  fi
  # Żądanie z tego startu czeka na restart, a z poprzedniego musi się już zgadzać z faktycznym trybem.
  if [ -r /var/lib/gpu-mode-target ]; then
    read -r target boot < /var/lib/gpu-mode-target
    if [ "$boot" = "$(cat /proc/sys/kernel/random/boot_id)" ]; then
      gpuset=$target
    elif [ "$target" != "$gpunow" ]; then
      gpufail=$target
    fi
  fi
fi

# Słuchawki: pierwsze urządzenie headset/headphones z jednego zrzutu upower.
headset=$(upower --dump 2>/dev/null | awk -F': *' '
  /^Device:/ { on = ($0 ~ /headset|headphones/) && !done }
  on && /model:/ { name = $2 }
  on && /percentage:/ { gsub("%", "", $2); pct = int($2); done = 1; on = 0 }
  END { if (done) { gsub(/["\\]/, "", name); printf "\"%s\" %d", name, pct } }')
hname=${headset% *}; hpct=${headset##* }
[ -n "$headset" ] || { hname='""'; hpct=null; }

printf '{"usage":%s,"profile":"%s","vpn":"%s","vpns":%s,"ks":%s,"manualOff":%s,"noVpnNet":%s,"gpu":"%s","bat":%s,"ac":%s,"watts":%s,"batState":"%s","top":%s,"charge":"%s","hasCharge":%s,"hasGpu":%s,"hasVpn":%s,"gpuSet":"%s","gpuNow":"%s","gpuFail":"%s","headset":%s,"headsetPct":%s,"now":%s}\n' \
  "$usage" "$profile" "$vpn" "$vpns" "$ks" "$off" "$novpn" "$gpu" "$bat" "$ac" "$watts" "$batstate" "$top" "$charge" "$hascharge" "$hasgpu" "$hasvpn" "$gpuset" "$gpunow" "$gpufail" "$hname" "$hpct" "$(date +%s%3N)"
