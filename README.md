# Wydma

A desktop widget for KDE Plasma 6: a column of cards in sand, sky and terracotta, made to sit on a desert wallpaper. The interface is in Polish.

- **Clock** and date.
- **Claude limits**: the 5-hour and weekly usage, read from the file the [Claudbar](https://github.com/siw0o0/claudbar) plugin writes (`~/.cache/claudbar/usage.json`). Without Claudbar the card says there is no reading.
- **CPU and GPU** load and temperature; **memory**, VRAM and disk; **network** speed with a graph.
- **Power**: battery, power profile, the headset's battery.
- **VPN** state, with a warning while Proton VPN's kill switch blocks the network.

It was built for one laptop (a Lenovo Legion with an NVIDIA card) and says so in places:

- An NVIDIA card is read only on AC power, because the reading keeps it awake.
- The battery is `BAT0` and the charger `ADP0`.

## Install

```bash
git clone https://github.com/siw0o0/wydma.git
cd wydma
./install.sh
```

Then add **Wydma** to the desktop from *Add Widgets…*.

## Your settings

Nothing of yours is in the package: what differs between machines goes in `~/.config/wydma/`, and every file there is optional.

- `gpu`: the card's id in the system sensors, one line such as `gpu/gpu1` (System Monitor shows the ids). Without it the first card, `gpu/gpu0`, is read.
- `novpn`: Wi-Fi networks where the VPN stays off, one name per line.
- `plan` and `plan-open`: the class schedule, described below.

## Optional parts

Cards and switches that need a helper show up only when the helper is installed. The helpers are in `helpers/`; read them before installing, two of them run as root.

- **Charging mode** (`helpers/battery-mode`): switches the battery between conservation, standard and fast charging through `charge_types`. Install it as `/usr/local/sbin/battery-mode` and let your user run it without a password:

  ```
  # /etc/sudoers.d/91-battery-mode
  yourname ALL=(root) NOPASSWD: /usr/local/sbin/battery-mode
  ```

- **Graphics mode** (`helpers/gpu-mode`): Hybrid, iGPU or dGPU on Legion laptops with the `legion_laptop` driver, applied at the next boot. Install it as `/usr/local/sbin/gpu-mode` with a sudoers line like the one above.
- **VPN switch and list** (`helpers/protonvpn-auto`): keeps Proton VPN (its CLI) on everywhere except the networks listed in `~/.config/wydma/novpn`, and switches to other VPN profiles from NetworkManager. Install it as `~/.local/bin/protonvpn-auto`; run it from a NetworkManager dispatcher script and at login to have it follow network changes.
- **Next classes**: an executable `~/.config/wydma/plan` that prints one line of JSON, `{ "pobrano": ISO time, "zajecia": [{ "przedmiot", "forma", "start", "koniec", "sala", "budynek", "uwaga" }] }` (`start` and `koniec` are ISO times). A click on the card runs `~/.config/wydma/plan-open`, if there is one.

## Uninstall

```bash
./install.sh remove
```

## License

Wydma is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. See [LICENSE](LICENSE).

Copyright (C) 2026 siw0o0
