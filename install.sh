#!/bin/sh
# Installs (or upgrades) the Wydma desktop widget for the current user, with a "Wydma" entry in the
# application menu that opens its settings.
# Usage: ./install.sh                  install or upgrade
#        ./install.sh --desktop-icon   also put the settings shortcut on the desktop
#        ./install.sh remove           uninstall everything
set -eu

here=$(cd "$(dirname "$0")" && pwd)
data=${XDG_DATA_HOME:-$HOME/.local/share}
bin=$HOME/.local/bin
desktop=$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "kpackagetool6 not found: Wydma needs KDE Plasma 6." >&2
    exit 1
fi

if [ "${1:-}" = "remove" ]; then
    kpackagetool6 -t Plasma/Applet -r wydma || true
    rm -f "$bin/wydma-settings" "$data/applications/wydma.desktop" "$data/icons/hicolor/scalable/apps/wydma.svg" "$desktop/wydma.desktop"
    exit 0
fi

if kpackagetool6 -t Plasma/Applet -s wydma >/dev/null 2>&1; then
    kpackagetool6 -t Plasma/Applet -u "$here/plasmoid"
else
    kpackagetool6 -t Plasma/Applet -i "$here/plasmoid"
fi

# The settings launcher: a script, an icon and a menu entry that runs the script.
mkdir -p "$bin" "$data/applications" "$data/icons/hicolor/scalable/apps"
install -m 755 "$here/launcher/wydma-settings" "$bin/wydma-settings"
install -m 644 "$here/launcher/wydma.svg" "$data/icons/hicolor/scalable/apps/wydma.svg"
sed "s|@EXEC@|$bin/wydma-settings|" "$here/launcher/wydma.desktop.in" > "$data/applications/wydma.desktop"
if [ "${1:-}" = "--desktop-icon" ] && [ -d "$desktop" ]; then
    install -m 755 "$data/applications/wydma.desktop" "$desktop/wydma.desktop"
fi
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$data/applications" >/dev/null 2>&1 || true

cat <<'EOT'

Widget installed. Right-click the desktop > Enter Edit Mode > Add Widgets… > search "Wydma".
Its settings: right-click the widget > Configure Wydma…, or "Wydma" in the application menu.
(After an upgrade, restart Plasma to load the new version: kquitapp6 plasmashell && kstart plasmashell)
EOT
