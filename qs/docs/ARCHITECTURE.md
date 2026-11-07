# Architecture

Everything below is read from the source tree as it is; nothing is planned behavior.
Prose (comments, docs, log messages, UI strings) is American English: "color", "center", "behavior".

## Process topology

Three processes exist:

1. **`qs-shell`** — `quickshell -p share/qs/shell` (`nix/package.nix`). `qml/shell/shell.qml` is a
   `ShellRoot` with a `Variants { model: Quickshell.screens }` that instantiates one `ClockBar`
   (`PanelWindow`, `WlrLayer.Overlay`) per output, plus three `IpcHandler`s (`launcher`, `settings`,
   `status`). All state is QML singletons inside this one process; compositor services come from
   Quickshell's native modules (`Quickshell.Services.*`, `FileView`, `Socket`, `Process`).
2. **`qs-fan-helper`** (`fan-helper/`, root, systemd socket‑activated at `/run/qs-fan-helper.sock`).
3. **`qs-secret`** (`secure-helper/`, invoked as `qs-askpass` or `pinentry-qs`), a short‑lived client that
   connects to the shell's secure socket and exits.
4. **`qs-meter`** (`meter-helper/`), a stdin→stdout filter: raw s16 mono PCM in, `peak rms` lines out at
   a fixed cadence. The shell runs `pw-record … | qs-meter` per metered device, only while a meter is on
   screen (`Status/Meter`); closing the read end tears the pipeline down.

### Singletons (from each directory's `qmldir`)

**`Shell` (`qml/shell/`)**
- `ClockConfig` — the config file: reads, validates, owns every setting, and is the only writer.
- `LocationServices` — system-wide GeoClue switch via `systemctl start qs-location-on/off.service`.

**`Common`**
- `Theme` — colors, metrics, and the motion vocabulary (`normalizeMotion`, `durationFor`, `easingFor`).
- `I18n` — `tr()` keyed on `locale` (`en`/`jp`) so bindings retranslate live; `ja.js` holds strings.
- `FocusedOutput` — the output Niri has focused, for "open on this screen" shortcuts.

**`Control`**
- `FanControl` — client of the fan helper socket; holds the lease while fans are shown or manually set.
- `FanSource` — fan RPM straight from sysfs when the helper isn't reporting them.
- `DualSenseLights` — DualSense/DualSense Edge lightbars (`/sys/class/leds/inputN:rgb:indicator` under a
  `054C:0CE6`/`054C:0DF2` HID device, matched to the Bluetooth address by `/sys/class/input/inputN/uniq`, looked
  up only when a gamepad connects); paints each controller saved in `dualsense`, running its effect at 25 fps
  and easing every change over 400 ms, writing `multi_intensity` through one long-lived `sh` fed over stdin.
- `SystemSource` — CPU/memory usage samples for the usage tiles.
- `WiredSource` — NetworkManager global switch and default route via `nmcli`/`ip`.

**`Launcher`**
- `LauncherState` — open/closed and which output (`screenName`) the launcher is on.
- `AppSearch` — installed applications ranked against the query; launch counts bias ties.
- `FileSearch` — home-folder search through `fd`.
- `Calculator` — arithmetic parser for typed expressions; never evaluates input as code.

**`Settings`**
- `SettingsModel` — every setting's control, `get`/`set` against `ClockConfig`, shared by pages and launcher.
- `SettingsState` — `toggleRequested(screenName)` for Super+Comma on the focused output.

**`Notifications`**
- `NotificationService` — the session's only notification daemon; tracks notifications and expires them on
  one timer armed for the soonest countdown.

**`Secure`**
- `SecureInput` — serves `$XDG_RUNTIME_DIR/qs-secure.sock`, polkit agent flows, the prompt queue.
- `SecureRequest` — turns requester metadata plus `/proc` lineage into prompt text, icon, kind.

**`Status`**
- `Brightness` — reads/writes `/sys/class/backlight/*/brightness` through `FileView`; sysfs has no inotify, so
  it polls only while a slider shows it, and a key step reads the live value first.
- `Media` — selects the active MPRIS player and emits `mediaEvent`.
- `Meter` — live output/input signal (dB-scaled peak, 60 dB range) via `pw-record | qs-meter` taps that
  run while `watchers > 0`; `inputInUse` is true when a program other than the taps or a filter chain
  (`node.link-group`) is capturing. Taps are named `qs-meter` so they can exclude themselves.

**`Weather`**
- `WeatherService` — NWS points/stations/forecast/alerts, Open‑Meteo daily and air quality, GeoClue `where-am-i`.
- `WeatherAlerts` — converts alerts and imminent precipitation into shell notifications; remembers sent keys.

## State ownership

| State | Owner | Persistence |
| --- | --- | --- |
| All user settings | `ClockConfig` | `$QS_CONFIG_FILE` / `~/.config/qs/config.json`; read with `FileView { watchChanges: true }`, written with `FileView { atomicWrites: true }` from `save()` |
| Per-screen panel state (calendar, control center, notes, weather open) | each `ClockBar` instance | none |
| Launcher open + screen | `LauncherState` | none |
| Launcher app usage counts | `AppSearch` | `$XDG_CACHE_HOME/qs-launcher.json` (else `~/.cache/`) |
| File preview renders | `FilePreview` | `$XDG_RUNTIME_DIR/qs-preview/<md5>.png` (else `/tmp`) |
| Weather alert "already notified" keys | `WeatherAlerts` | `$XDG_CACHE_HOME/qs-weather-alerts.json`, atomic writes |
| Fan lease / manual set | `FanControl` ↔ helper | none; the helper's own state dies with the connection |
| Location on/off | NixOS oneshots | `/var/lib/qs/location-off` marker, read by `LocationServices` |

Config write path: a Settings control calls its `set` → assigns a `ClockConfig` property → `ClockConfig.save()`
serializes the whole document (preserving unknown keys it read) and writes atomically. `apply()` runs on every
file change; a value failing validation logs `qs config: invalid <key>` and keeps the in-memory value, so a
hand‑typed mistake is never rewritten into the file. `Theme.motionDuration`, `Theme.springOvershoot`,
`Theme.palette`/`dark`, and `I18n.locale` mirror `ClockConfig` so `Common` never imports the shell module.

## Design language

One language, the notebook: a ruled instrument, a page with gauges on it. Two pages — Night (black) and
Paper (`paper`, ePaper-like) — written in pens. Every component is built from the shared parts below, so a
panel never mixes idioms. Principles kept from the platform HIGs: one primary reading per panel, content
over chrome, 44px targets, every state visible (hover, press, focus, on).

### Color

- **By function.** Each color has one job. Readings `textPrimary`; labels, captions and functions
  `textSecondary`; `today` for the one active/armed state per surface (an "on" knob, today's date, a chosen
  option's underline, a mic being listened to) with `todayInk` for content on it; `danger`/`dangerMark` only
  for destructive or warning states; `charging` for charging and good air. Never color for decoration.
- **Palettes** (`theme.colors`) fill those functions. `pens` is the shell's own: Uni-ball Signo's colored
  blacks, lightened for Night — Blue Black is `today`, Bordeaux is `danger`, Green Black is `charging` —
  with graphite and pencil on Paper. `matugen` fills the same slots from roles generated from the wallpaper
  (`Common/Matugen`: primary → `today`, error → `danger`, tertiary → `charging`, surface/on-surface → the
  page and its writing), regenerated each time it's chosen and cached in `$XDG_CACHE_HOME/qs-matugen.json`;
  until a scheme exists the pens stand in. Another engine is a new set in `Theme` filling the same slots.
- **Light and dark.** `theme.appearance` flips every slot; nothing assumes a black surface (overlays are
  `lift`/`press`, never literal white).

### Rules

- **Tokens, not literals.** Colors come only from `Theme`'s semantic slots (`surface`, `textPrimary`/
  `textSecondary`, `rule`/`stroke`/`edge`, `track`, `statusTrack`/`statusDim`, `lift`/`press`/`clear`,
  `today`/`todayInk`/`todayDim`, `danger`/`dangerMark`/`dangerInk`, `charging`, `aqi*`); faces from
  `fontFamily`/`latinFontFamily`/`fontWeightStrong`; shape from
  `radius` (housings), `radiusInput` (rows, fields, hover boxes), `knobSize`, `rowHeight`, `tileGap`; lines
  from `line`/`lineStrong` (a 0.38 pen's line and a fader's track); sizes via `Theme.px`.
- **Shared parts.** `Common/SectionHeader`, `Common/Rule`, `Common/Field`, `Status/Knob`, `Control/Tile`/
  `ToggleTile`/`SliderTile`/`ListRow`, `Settings/Options`/`Stepper`, `Clock/BackButton`/`SettingsButton`/
  `MonthArrow`.
- **Page, not cards.** Groups are separated by `Rule`s; side-by-side cells by a vertical rule. No filled
  containers. Rows take `lift`/`press` and a `line` outline in `today` on focus.
- **Knob, then row.** Every actionable row starts with a `Status/Knob`: clicking it acts at once (mute,
  disable Wi‑Fi, flip a fan to manual); clicking the rest of the row goes deeper. Off an unfilled `stroke`
  circle, on a `today` disc.
- **Faders are rulers** (`lineStrong` track, quarter ticks, no thumb); **scales are graph paper** (gridlines
  at round values, spans with end ticks, the current value a short tick); **fields are written on a line**
  (`Field` underline, `today` on focus). AQI bands appear as a marker, never a gradient.
- **Reel digits.** Any number that can change is a `Clock/TickerNumber`, so values roll the way the time
  does. Digits set in `latinFontFamily`, so a locale switch doesn't resize numbers.
- **Ring readouts.** A live 0..1 reading (meter, usage, battery) may ring its glyph (`Status/StatusArc`);
  never the setpoint its own slider already shows.
- **Drawn glyphs.** Icons are `StatusGlyph` stroke paths (Lucide), never an icon font.
- **Type.** IBM Plex; sentence-case captions on their rule.

## Motion system

- `clock.motion` is one of `spring | easeIn | linear | easeOut | none` (`Theme.normalizeMotion`, unknown → `spring`).
- `Theme.durationFor(motion)` is `0` for `none`, else `Theme.motionDuration` (`clock.duration`).
  `Theme.easingFor(motion)` maps to `Easing.OutBack` (spring), `InCubic`, `Linear`, `OutCubic`.
- `Common/Tween.qml` is a `NumberAnimation` with `aim(next)`: snaps when motion is `none`, ignores aims at
  the resting value, and restarts from the current value otherwise. Panels drive progress reals
  (`openProgress`, `presenceP`, `notchAmount`, …) with Tweens rather than `Behavior`s.
- `Neck.qml` is the surface strip between adjacent bar circles: its cross thickness follows `release`
  (a water‑drop neck letting a circle go as it opens) and `join` (pill→notch fusion), both smoothstepped.

## Panel coordination (`ClockBar.qml`)

- One bar per screen; `calendarOpen | controlsOpen | notesOpen | weatherOpen` → `anyOpen`.
- `closeExcept(kept)` closes every other panel; the `on*OpenChanged` handlers call it so opening one closes
  the rest. `closePanels()` = `closeExcept(null)`; `closeAll()` also closes the launcher.
- The secure prompt (`secureShown`, first screen only) and the launcher (`launcherShown`, on
  `LauncherState.screenName`) *cover* the bar: `coverFade` dims everything under them and opening either
  closes the panels.
- `WlrLayershell.keyboardFocus` is `Exclusive` while `anyOpen || covered`, else `None`, so only one
  keyboard grab exists per screen.
- `exclusiveZone` is non‑zero only for the `notch` housing while it is not moving.
- Dismiss window: a second full‑screen, transparent `PanelWindow` (`WlrLayer.Top`, no keyboard focus) is
  mapped `2 × Theme.motionDuration` after something opens (`dismissReady`) and only while no panel has the
  pointer down; any click on it calls `closeAll()`. It is unmapped as soon as closing starts so the
  compositor doesn't blend a screen‑sized layer during the animation.
- Switching `clock.presentation` while the control center is open folds the panel first, moves the housing,
  then reopens the same page (`reopenPage`).

## Trust boundaries

**Secure socket** (`SecureInput`, `$QS_SECURE_SOCKET` or `$XDG_RUNTIME_DIR/qs-secure.sock`). Any process
running as the same uid can connect and request a prompt. The client sends `pid`; the shell reads that
process's lineage itself via a `/proc` probe (`SecureInput.readLineage` → `SecureRequest.parseLineage`) and
builds title/icon from that, never from client‑supplied names beyond the prompt text. A missing or bogus pid
yields a generic title. Repeated requests from the same pid within 15 s are shown as "Wrong password". This
is **same‑user trust**, not a privilege boundary: a malicious same‑uid process can already read the user's
files and could spoof a prompt. Over SSH the helper refuses to use the graphical prompt.

**Fan socket**. `/run/qs-fan-helper.sock` is `root:qs-fans 0660`; group membership is the whole
authorization. The helper never trusts the client beyond that: the request schema is `status | set | auto |
release` (`deny_unknown_fields`), at most 8 clients and 4 KiB per request, one lease holder at a time, the
policy (discovery defaults or an explicit device/channel allowlist with `minimumPercent`) comes from
root‑owned `/etc/qs/fan-policy.json`, and a 200 ms watchdog revokes manual control on lease expiry,
disconnect, or a thermal sensor at `criticalCelsius`. "Auto" is the `pwmN_enable` value the firmware had
before the helper first touched a channel, remembered in `/run/qs-fan-helper/baseline.json`
(`RuntimeDirectoryPreserve`) so `ExecStopPost --restore` after a crash can put it back. The service runs
with an empty capability set under a strict systemd sandbox.

**Backlight and lightbars**. The NixOS udev rules `chgrp video` + `chmod g+w` on
`/sys/class/backlight/*/brightness`, and `chgrp users` + `chmod g+w` on hid-playstation's
`inputN:rgb:indicator/multi_intensity`, let the shell write both directly; no helper is involved.

**Location**. `LocationServices` can only `systemctl start qs-location-on/off.service`; the polkit rule in
`nixos-module.nix` allows exactly those two units for a local, active session.

## Known limitations

- Weather is **US‑only**: conditions, hourly/daily forecast and alerts come from `api.weather.gov`;
  Open‑Meteo supplies only the 10‑day outlook, sunrise/sunset and air quality; the location picker
  geocodes with `countryCode=US`. This is a stated scope, not a bug.
- The secure prompt is same‑uid trust (above). Neither socket uses `SO_PEERCRED`: the fan helper relies on
  filesystem group permissions and the shell relies on the client‑supplied `pid` plus `/proc`.
- Secrets are prompted on `Quickshell.screens[0]` only.
- Discovery guards manual control only with sensors from a fixed driver list (`k10temp`, `coretemp`,
  `zenpower`, `cpu_thermal`, `soc_thermal`, `amdgpu`); a host with none of them is read-only unless
  `fanControl.devices` names its sensors explicitly.
- The config file is reloaded on every change but a parse error leaves the previous document in place and
  logs `qs config: <error>`.

## Decisions

- **No Rust user daemon.** Quickshell native modules cover what it was for (`Quickshell.Services.*`:
  Networking, Bluetooth, Pipewire, UPower, Notifications, Polkit; `FileView` atomic writes). Only two
  out‑of‑process pieces exist: `fan-helper` (root, group `qs-fans` socket at `/run/qs-fan-helper.sock`,
  lease = open socket) and `secure-helper` (askpass/pinentry client of the shell's
  `$XDG_RUNTIME_DIR/qs-secure.sock`). The shell (`ClockConfig.qml`) is the sole config writer; invalid
  values are warned and kept in memory, never persisted.
- **Weather is NWS‑first (US only)** with Open‑Meteo for the 10‑day outlook and air quality; a stated
  limitation, not a bug.
- **Do Not Disturb exists** and means: no peek card, no badge; notifications still queue. Arrival feedback
  = the circle plus a 5 s peek card (`NotificationCenter.peekDwell`).
- **Secure prompt trust boundary:** any same‑uid process may connect to the secure socket; the shell
  derives the requester's process lineage itself from the `pid` the client sends via `/proc`; it never
  trusts client‑supplied titles beyond the prompt text. This is same‑user trust, not a privilege boundary.
