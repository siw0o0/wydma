# Wydma

A desktop widget for KDE Plasma 6: a column (or several) of cards with a clock, your schedule, Claude limits, system meters, power and VPN. Every card can be turned off, reordered and tuned from a settings dialog, and the whole widget fits itself to the screen it is on.

Interface in Polish and English.

## Cards

| Card | Shows |
| --- | --- |
| Clock | time and date, 12 or 24 hours, optional seconds |
| Schedule | the current and next classes or meetings, from your own command |
| Claude limits | the 5-hour and weekly usage, from the [Claudbar](https://github.com/siw0o0/claudbar) plugin's file |
| Processor and graphics | load and temperature of the CPU and a GPU |
| Memory | RAM, swap, VRAM and disk |
| Network | download and upload with a graph |
| Power | battery, power draw, power profile, charging mode, headset battery |
| Graphics mode | Hybrid, iGPU or dGPU on Legion laptops |
| VPN | state, a switch and the list of VPN profiles |
| System | distribution, kernel, Plasma version, uptime |
| Top memory | the programs using the most RAM |
| Note | your own text |
| Custom | the output of any command, refreshed on a timer |

A card with nothing to show hides by itself: no battery, no VPN profile, no schedule.

## Install

```bash
git clone https://github.com/siw0o0/wydma.git
cd wydma
./install.sh
```

Then add **Wydma** to the desktop from *Add Widgets…*, and place and size it in edit mode.

The installer also adds a **Wydma** entry to the application menu that opens the widget's settings. For a shortcut on the desktop as well, run `./install.sh --desktop-icon`.

## Settings

Right-click the widget and choose *Configure Wydma…*, or start **Wydma** from the application menu (`wydma-settings` from a terminal).

- **Cards**: which cards are shown and in what order.
- **Look**: seven colour sets (four dark, two light, one following the Plasma colour scheme) with a live preview, card opacity, corner radius, shadow, title style, the font, and the language.
- **Layout**: scale from 50% to 200%, one to four columns or automatic, which edge the widget hugs, the space between cards.
- **Clock**: 12/24 hours, seconds, digit size, light or dark text, date format.
- **Sensors**: refresh rate, which graphics card, disk and network interface to read, units (°C/°F, bytes/bits), and the percentages and temperatures at which values turn amber and red.
- **Sources**: the Claude limits file, the schedule command, Wi-Fi networks without VPN, the note and the custom command.

### Screens of any size

The widget never spills out of the area you gave it. With *Shrink everything when it does not fit the height* on, it scales down on a small screen. With automatic columns it also tries every column count and takes the one that lets the cards be largest, so a wide area gets the cards side by side and a tall one keeps them in a column.

## Optional parts

Switches that need a helper show up only when the helper is installed. The helpers are in `helpers/`; read them before installing, two of them run as root.

- **Charging mode** (`helpers/battery-mode`): switches the battery between conservation, standard and fast charging through `charge_types`. Install it as `/usr/local/sbin/battery-mode` and let your user run it without a password:

  ```
  # /etc/sudoers.d/91-battery-mode
  yourname ALL=(root) NOPASSWD: /usr/local/sbin/battery-mode
  ```

- **Graphics mode** (`helpers/gpu-mode`): Hybrid, iGPU or dGPU on Legion laptops with the `legion_laptop` driver, applied at the next boot. Install it as `/usr/local/sbin/gpu-mode` with a sudoers line like the one above.
- **Proton VPN automation** (`helpers/protonvpn-auto`): keeps Proton VPN (its CLI) on everywhere except the Wi-Fi networks listed in the settings, and switches to other VPN profiles. Install it as `~/.local/bin/protonvpn-auto`; run it from a NetworkManager dispatcher script and at login to have it follow network changes. Without it the VPN card still works: it connects and disconnects NetworkManager's VPN profiles directly.
- **Schedule**: a command that prints one line of JSON, `{ "pobrano": ISO time, "zajecia": [{ "przedmiot", "forma", "start", "koniec", "sala", "budynek", "uwaga" }] }` (title, kind, start, end, room, building, remark; `start` and `koniec` are ISO times, the rest is optional). Set it in the settings, or put an executable at `~/.config/wydma/plan`.

## Notes

- An NVIDIA card is read only on mains power by default, because the reading keeps it awake; there is a setting to read it on battery too.
- The status script (`plasmoid/contents/code/status.sh`) runs every 10 seconds and is kept light: one `nmcli`, one `upower`, the power profile over D-Bus.

## Uninstall

```bash
./install.sh remove
```

## License

Wydma is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. See [LICENSE](LICENSE).

Copyright (C) 2026 siw0o0
