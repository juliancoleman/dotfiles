# Architecture

Everything below is read from the source tree as it is; nothing is planned behaviour.

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
- `Theme` — colours, metrics, and the motion vocabulary (`normalizeMotion`, `durationFor`, `easingFor`).
- `I18n` — `tr()` keyed on `locale` (`en`/`jp`) so bindings retranslate live; `ja.js` holds strings.
- `FocusedOutput` — the output Niri has focused, for "open on this screen" shortcuts.

**`Control`**
- `FanControl` — client of the fan helper socket; holds the lease while fans are shown or manually set.
- `FanSource` — fan RPM straight from sysfs when the helper isn't reporting them.
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
- `NotificationService` — the session's only notification daemon; tracks and expires notifications.

**`Secure`**
- `SecureInput` — serves `$XDG_RUNTIME_DIR/qs-secure.sock`, polkit agent flows, the prompt queue.
- `SecureRequest` — turns requester metadata plus `/proc` lineage into prompt text, icon, kind.

**`Status`**
- `Brightness` — reads/writes `/sys/class/backlight/*/brightness` through `FileView`; polls because sysfs has no inotify.
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
| Per-screen panel state (calendar, control centre, notes, weather open) | each `ClockBar` instance | none |
| Launcher open + screen | `LauncherState` | none |
| Launcher app usage counts | `AppSearch` | `$XDG_CACHE_HOME/qs-launcher.json` (else `~/.cache/`) |
| File preview renders | `FilePreview` | `$XDG_RUNTIME_DIR/qs-preview/<md5>.png` (else `/tmp`) |
| Weather alert "already notified" keys | `WeatherAlerts` | `$XDG_CACHE_HOME/qs-weather-alerts.json`, atomic writes |
| Fan lease / manual set | `FanControl` ↔ helper | none; the helper's own state dies with the connection |
| Location on/off | NixOS oneshots | `/var/lib/qs/location-off` marker, read by `LocationServices` |

Config write path: a Settings control calls its `set` → assigns a `ClockConfig` property → `ClockConfig.save()`
serialises the whole document (preserving unknown keys it read) and writes atomically. `apply()` runs on every
file change; a value failing validation logs `qs config: invalid <key>` and keeps the in-memory value, so a
hand‑typed mistake is never rewritten into the file. `Theme.motionDuration`, `Theme.springOvershoot`, and
`I18n.locale` mirror `ClockConfig` so `Common` never imports the shell module.

## Design language

The bar's instruments are the identity; panels are built from the same parts rather than their own.

- **Reel digits.** Any number that can change is a `Clock/TickerNumber` (built on `DigitTicker`), so a
  percentage, temperature, or count rolls the way the time does. Static text stays `Text`.
- **Ring readouts.** A 0..1 reading is drawn as `Status/StatusArc` around its glyph (the status circle,
  weather circle, `Status/Knob` with `level`). A ring always shows something *live* — a meter, a usage, a
  battery — never the setpoint its own row's slider already shows (Ableton's meter beside the fader).
  Where a row has a slider but no live signal (brightness), the knob has no ring; the glyph's own fill
  (`StatusGlyph.level`) carries the coarse level.
- **Colour by function class.** Readings `textPrimary`; labels and captions `textSecondary`; one `today`
  per surface for the active/armed state (an "on" knob, a mic being listened to); `bordeaux`/`danger`
  only for destructive or warning states. Never colour for decoration.
- **Knob, then row.** Every actionable row starts with a `Status/Knob`: clicking it acts at once (mute,
  disable Wi‑Fi, flip a fan to manual); clicking the rest of the row goes deeper. `on` fills it with
  `Theme.today`.
- **One flat fill, one hairline.** Containers (`Control/Tile`) are `Theme.track` with a 1px `Theme.edge`
  border that turns `Theme.today` on focus. No tonal elevation stacks, no blur. Hover tints with
  `Theme.lift`; knobs use `knobFill`/`knobLift`.
- **Tokens over literals.** `Theme` holds the type ramp (`textCaption` 10 … `textDisplay` 22, with
  `textTitle` = the clock's `horizontalDigit`), shape (`radius` 12 for containers, `radiusInput` 6 for
  rows and lanes inside them, `knobSize`/`knobInset`/`knobGap`, `rowHeight`, `tileGap`), and the overlay
  colours above. New components take these; `Control` and `Weather` are converted, other panels still
  carry literal sizes and `Qt.rgba` overlays to be swept. Digits always set in `latinFontFamily`
  (`DigitTicker`), so a locale switch to the JP face doesn't resize numbers.
- **Drawn glyphs.** Icons are `StatusGlyph` stroke paths (Lucide), never an icon font.

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
- Switching `clock.presentation` while the control centre is open folds the panel first, moves the housing,
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
authorisation. The helper never trusts the client beyond that: the request schema is `status | set | auto |
release` (`deny_unknown_fields`), at most 8 clients and 4 KiB per request, one lease holder at a time, the
device/channel allowlist and `minimumPercent` come from root‑owned `/etc/qs/fan-policy.json`, and a
200 ms watchdog revokes manual control on lease expiry, disconnect, or a thermal sensor at
`criticalCelsius`. The service runs with an empty capability set under a strict systemd sandbox and
`ExecStopPost --restore`.

**Backlight**. The NixOS udev rule `chgrp video` + `chmod g+w` on `/sys/class/backlight/*/brightness`
lets the shell (a `video` member) write brightness directly; no helper is involved.

**Location**. `LocationServices` can only `systemctl start qs-location-on/off.service`; the polkit rule in
`nixos-module.nix` allows exactly those two units for a local, active session.

## Known limitations

- Weather is **US‑only**: conditions, hourly/daily forecast and alerts come from `api.weather.gov`;
  Open‑Meteo supplies only the 10‑day outlook, sunrise/sunset and air quality; the location picker
  geocodes with `countryCode=US`. This is a stated scope, not a bug.
- The secure prompt is same‑uid trust (above). Neither socket uses `SO_PEERCRED`: the fan helper relies on
  filesystem group permissions and the shell relies on the client‑supplied `pid` plus `/proc`.
- Secrets are prompted on `Quickshell.screens[0]` only.
- `fanControl.devices.*.identity` accepts only `nct6797`.
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
