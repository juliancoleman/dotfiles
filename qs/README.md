# qs

A Quickshell desktop shell for Niri. One bar per screen holds a clock that opens into a calendar, a status
circle that opens into a control centre (Wi‑Fi, Bluetooth, audio, power, fans, settings), a notification
circle, a weather circle, an application/file/calculator launcher, and a secure prompt that answers sudo,
ssh, git, gpg and polkit requests. It is QML running inside Quickshell plus two small Rust helpers; there is
no user daemon.

## Requirements

- Wayland with the [Niri](https://github.com/YaLTeR/niri) compositor (the shell uses `niri` on `PATH` and
  the Niri keybinds below).
- [Quickshell](https://quickshell.outfoxxed.me/) 0.3.x (the Home Manager module installs `pkgs.quickshell`).
- NixOS + Home Manager for the packaged install. The `qs-shell` wrapper also expects `curl`, `fd`, `nmcli`,
  `pdftoppm`, `wl-copy`, `systemctl`, `xdg-open` on `PATH`; `nix/package.nix` provides them.

## Install (flake)

`flake.nix` exposes, for `aarch64-linux` and `x86_64-linux`:

| Output | Content |
| --- | --- |
| `packages.<system>.default`, `packages.<system>.qs` | `qs-shell` wrapper around `quickshell -p share/qs/shell` plus `share/qs/config/default.json` |
| `packages.<system>.fan-helper` | `qs-fan-helper` (root fan control helper) |
| `packages.<system>.secure-helper` | `qs-secret` with `qs-askpass` and `pinentry-qs` symlinks |
| `packages.<system>.meter-helper` | `qs-meter` (PCM → peak/RMS filter behind the live level rings; on `qs-shell`'s PATH with `pw-record`) |
| `nixosModules.default` / `nixosModules.qs` | `services.qs.*` |
| `homeManagerModules.default` / `homeManagerModules.qs` | `programs.qs.*` |

```nix
inputs.qs.url = "github:<you>/qs";            # the author's dotfiles use `path:../qs`
# nixosConfigurations.<host>.modules:
qs.nixosModules.default
{ services.qs = { enable = true; wallpaper = ./wallpaper.jpg; }; }
# home-manager.users.<you>:
{ imports = [ qs.homeManagerModules.default ]; programs.qs.enable = true; }
```

### `services.qs` (NixOS, `nix/nixos-module.nix`)

| Option | Type | Default |
| --- | --- | --- |
| `enable` | bool | `false` |
| `package` | package | `self.packages.<system>.default` |
| `wallpaper` | nullOr path | `null` — exposed at `/etc/qs/wallpaper` |
| `locationServices.enable` | bool | `false` — GeoClue + `qs-location-on`/`qs-location-off` oneshots, polkit rule, `where-am-i` |
| `fanControl.enable` | bool | `false` |
| `fanControl.package` | package | `self.packages.<system>.fan-helper` |
| `fanControl.users` | listOf str | `[ ]` — added to group `qs-fans` |
| `fanControl.leaseSeconds` | ints.between 2 30 | `5` |
| `fanControl.renewalSeconds` | ints.positive | `2` (asserted `< leaseSeconds`) |
| `fanControl.defaultMinimumPercent` | ints.between 0 100 | `0` — floor for discovered fans |
| `fanControl.thermal.warningCelsius` / `.criticalCelsius` | number | `85` / `95` (asserted warning < critical) |
| `fanControl.devices` | listOf device | `[ ]` — empty means discover |

With `devices = [ ]` the helper discovers the hardware itself (see *Fan control*). Each explicit
`fanControl.devices.*` entry instead names `identity` (the hwmon `name`), `channels` (non-empty list of
`{ name: str; channel: 1–16; minimumPercent: 0–100 }`), `thermalSensors` (non-empty list of
`{ identity: str; input: 1–64; warningCelsius: number; criticalCelsius: number }`, warning asserted below
critical). The module also enables `services.upower` and adds a udev rule making
`/sys/class/backlight/*/brightness` group‑writable by `video`.

### `programs.qs` (Home Manager, `nix/home-manager-module.nix`)

| Option | Type | Default |
| --- | --- | --- |
| `enable` | bool | `false` |
| `package` | package | `self.packages.<system>.default` |
| `wallpaper` | nullOr (path or absolute str) | `null` — `qs-wallpaper` user service (swaybg) omitted when null |
| `wallpaperMode` | enum stretch/fit/fill/center/tile | `"fill"` |
| `secureInput.enable` | bool | `true` |
| `secureInput.package` | package | `self.packages.<system>.secure-helper` |
| `secureInput.sudo` | bool | `true` — `SUDO_ASKPASS=qs-askpass`, shell alias `sudo = "sudo -A"` |
| `secureInput.ssh` | bool | `true` — `SSH_ASKPASS=qs-askpass`, `SSH_ASKPASS_REQUIRE=prefer` |
| `secureInput.gpg` | bool | `config.services.gpg-agent.enable` — `services.gpg-agent.pinentry.package` |
| `paths.configFile` | absolute str | `${xdg.configHome}/qs/config.json` |

Enabling installs the package, `quickshell`, `swaybg`, `ibm-plex`, `plemoljp-nf`; defines the
`qs-shell` user service (`PartOf graphical-session.target`, `QS_CONFIG_FILE` set); exports
`QS_CONFIG_FILE` and the askpass variables to both the login shell and `systemd --user`; and seeds
`paths.configFile` from `default.json` (mode 0600) only if the file does not exist.

## Niri keybinds

`shell.qml` registers three `IpcHandler` targets. Call them with `qs-shell ipc call <target> <function>`:

| Target | Functions |
| --- | --- |
| `launcher` | `toggle`, `open`, `close` |
| `settings` | `toggle` |
| `status` | `next`, `previous`, `playPause`, `brightnessUp`, `brightnessDown` |

```kdl
spawn-at-startup "qs-shell"
binds {
    Super+Space { spawn "qs-shell" "ipc" "call" "launcher" "toggle"; }
    Super+Comma { spawn "qs-shell" "ipc" "call" "settings" "toggle"; }
    XF86MonBrightnessUp   allow-when-locked=true { spawn "qs-shell" "ipc" "call" "status" "brightnessUp"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn "qs-shell" "ipc" "call" "status" "brightnessDown"; }
    XF86AudioNext  allow-when-locked=true { spawn "qs-shell" "ipc" "call" "status" "next"; }
    XF86AudioPlay  allow-when-locked=true { spawn "qs-shell" "ipc" "call" "status" "playPause"; }
    XF86AudioPrev  allow-when-locked=true { spawn "qs-shell" "ipc" "call" "status" "previous"; }
}
```

## Configuration

File: `$QS_CONFIG_FILE`, else `~/.config/qs/config.json` (`ClockConfig.qml`). The shell watches it and
reloads on change; Settings pages write it back atomically. A value the shell does not understand is
logged (`qs config: invalid <key>`) and the in-memory value is kept — it is neither replaced by a default
nor rewritten into the file. Keys and accepted values (defaults from `config/default.json`):

| Key | Accepted | Default | Meaning |
| --- | --- | --- | --- |
| `bar.placement` | `top` `right` `bottom` `left` | `right` | Screen edge the bar sits on |
| `bar.shadow` | bool | `true` | Drop shadow under the bar |
| `bar.scale` | number 0.75–2 | `1` | Multiplies every size token (`Theme.scale`); 0.05 steps. Output scale stays the compositor's job |
| `clock.hourCycle` | `12` `24` | `24` | Hour cycle |
| `clock.meridiem` | `shown` `hidden` | `shown` | Show AM/PM |
| `clock.locale` | `en` `jp` (`ja` accepted as `jp`) | `en` | Clock/UI language |
| `clock.motion` | `spring` `easeIn` `linear` `easeOut` `none` | `spring` | Animation style for every panel |
| `clock.presentation` | `pill` `notch` | `pill` | Bar housing: floating pill or fused notch with an exclusive zone |
| `clock.duration` | number 50–2000 | `250` | Animation duration in ms (`Theme.motionDuration`) |
| `clock.springOvershoot` | number 0–4 | `2` | Overshoot for `spring` motion |
| `launcher.view` | `list` `large` `small` | `large` | Launcher result layout (written by Settings, absent from `default.json`) |
| `status.batteryPercentage` | `always` `low` | `low` | When the battery percentage is shown |
| `notifications.doNotDisturb` | bool | `false` | No peek card, no badge; notifications still queue |
| `weather.enabled` | bool | `true` | Show the weather circle |
| `weather.units` | `imperial` `metric` | `imperial` | Temperature units |
| `weather.locationMode` | `exact` `automatic` | `exact` | Fixed `weather.location` or GeoClue `where-am-i` |
| `weather.location` | `null` or `{ name, region, latitude, longitude }` | `null` | Location picked in Settings (Open‑Meteo geocoding, US only) |
| `weather.alerts` | bool | `true` | Fetch NWS active alerts |

## Fan control

`services.qs.fanControl` runs `qs-fan-helper` as root behind the systemd socket `/run/qs-fan-helper.sock`
(owner `root`, group `qs-fans`, mode `0660`). Add your user to `fanControl.users` (or to `qs-fans`
yourself). The shell's `FanControl` singleton connects only while the fans page is open or a manual setting
is held; the lease is the open connection, renewed with `status` every `renewalSeconds`; disconnecting,
`leaseSeconds` of silence, or a sensor reaching `criticalCelsius` returns every fan to firmware control.
Policy is written to `/etc/qs/fan-policy.json` and changes restart the helper.

Discovery (`devices = [ ]`): every hwmon `pwmN` with a writable `pwmN_enable` and a spinning `fanN_input`
becomes a fan (label from `fanN_label`, else `Fan N`); headers reading 0 rpm at startup are skipped as
unpopulated. "Auto" is whatever `pwmN_enable` held before the helper touched the channel — recorded per
channel in `/run/qs-fan-helper/baseline.json` so `--restore` after a crash puts the same value back; a
channel that was already manual with no record is returned to full duty instead. Manual control is
guarded by every in-range input on `k10temp`, `coretemp`, `zenpower`, `cpu_thermal`, `soc_thermal`,
`amdgpu`; with none present the helper reports unavailable and the shell stays read-only. Any manual
write enters manual mode first, then sets the duty: nct6775-class chips reject `pwmN` writes while
automatic (EBUSY).

## Secure prompt

`secure-helper` builds one binary, `qs-secret`, installed with two names (`secure-helper/src/main.rs`):

- `qs-askpass` — used via `SUDO_ASKPASS`, `SSH_ASKPASS` (git follows `SSH_ASKPASS`), as set by
  `programs.qs.secureInput.sudo` / `.ssh`.
- `pinentry-qs` — an Assuan pinentry for gpg-agent, set by `programs.qs.secureInput.gpg`.

Both send one JSON line (`source`, `prompt`, `description`, `title`, `error`, `pid`) to
`$QS_SECURE_SOCKET` or `$XDG_RUNTIME_DIR/qs-secure.sock`, served by the shell's `SecureInput` singleton,
and read one JSON reply. Over SSH (`SSH_CONNECTION`/`SSH_TTY` set) they report unavailable so the caller
falls back to the terminal. See `docs/ARCHITECTURE.md` for the trust model.
