# Quickshell Specification

This document records binding product and architecture decisions. It has no open design questions. Exact colors, pixel-level optical corrections, and animation curves are implementation tuning performed against the live MacBook surface; they do not change the contracts below.

## 1. Scope and rollout

### Initial target

- Build and validate on the NixOS MacBook first.
- The compositor is **Niri 26.04**, not Hyprland.
- Keep compositor integration behind one adapter, but implement only Niri now.
- The desktop is outside the initial deployment. It will inherit the finished work after pulling the completed dotfiles changes and rebuilding.
- The production bar is always visible and reserves its configured edge through layer-shell exclusive space.

### DMS cutover

- Remove DankMaterialShell entirely rather than retaining it as a launcher, notification service, wallpaper owner, or OSD.
- The first MacBook cutover may happen after the foundation/workspace slice. A temporary period without notifications and later widgets is explicitly acceptable on this test machine.
- Replace the static wallpaper owner with a supervised `swaybg` user service.
- Replace the DMS `Super+Space` launcher with the shell's own launcher, which grows out of the bar's housing (`qs-shell ipc call launcher toggle`).
- Locking and screenshot scripts remain independent.
- Remove DMS-specific Niri layer rules, module imports, overlays, packages, and flake inputs when the MacBook configuration switches.

### Delivery order

1. Cutover foundation: repository/flake, Nix modules, supervised Quickshell, numeric workspaces, swaybg, and DMS removal.
2. Clock and calendar.
3. Status widget and required system backend.
4. Operational control center.
5. Notification daemon and panel.
6. Weather.
7. Settings application.
8. Launcher.

Configuration and CLI support grow with each vertical slice. Do not build the complete backend before visible consumers, and do not front-load the settings UI before widget contracts stabilize.

## 2. Repository, packaging, and processes

### Repository

- `~/code/qs` on the development Mac is the standalone local Git repository and Nix flake. No remote repository is required.
- The flake exports packages, a NixOS module, and a Home Manager module.
- Deploy only clean, committed snapshots by copying the project to `~/code/qs` on the target machine over SSH/SCP. Dotfiles consume that machine-local checkout as a path flake input. The Nix daemon never needs GitHub credentials.
- The local development repository remains the source of truth. Do not make independent source edits in a copied target tree; change and commit locally, then copy the next snapshot.
- The NixOS module installs and configures privileged system components and host safety policy.
- The Home Manager module installs user packages, seeds first-run configuration, and owns user services and swaybg.

### Runtime process boundary

- **Quickshell shell process:** bar surfaces, panels, Niri adapter, native Quickshell integrations, and notification daemon.
- **Quickshell settings process/package:** separate on-demand process so settings faults cannot kill the bar or notification daemon.
- **Rust user service:** unprivileged system integration not provided reliably by Quickshell. It owns typed NetworkManager and BlueZ D-Bus clients, weather/geocoding/cache, hardware and storage sampling, brightness integration, configuration validation/writes, and event delivery.
- **Rust privileged fan helper:** minimal system D-Bus service for validated fan capability discovery and leased PWM control.

Both the shell and Rust user service are supervised systemd user services started with the graphical session and restarted with bounded backoff. Settings is on demand.

### Native versus backend integrations

Use native Quickshell APIs for:

- MPRIS
- PipeWire
- UPower
- freedesktop notifications

Use a long-lived `niri msg --json event-stream` process inside the Quickshell process for workspaces, outputs, and focused-output state. This keeps the bar functional if the Rust service fails.

Use the Rust service for NetworkManager, BlueZ, weather, hardware/storage, brightness, and configuration. Do not repeatedly scrape localized `nmcli`, `bluetoothctl`, or sensor command output.

### IPC

- Use a versioned framed-JSON protocol over a `0600` Unix socket in `$XDG_RUNTIME_DIR`.
- Support request/response operations and a state/event stream for shell, settings, and CLI clients.
- Keep the protocol local to the logged-in user. Do not expose TCP/HTTP ports.
- If the Rust service is unavailable, native workspaces, clock, MPRIS, PipeWire, UPower, and notifications remain functional. Dependent widgets show an unavailable state rather than disappearing silently or restarting the shell.

## 3. Configuration and state

### Files and ownership

- Portable configuration: `~/.config/qs/config.json`.
- Machine-local/transient state: `~/.local/state/qs/state.json`.
- Weather payload caches and other replaceable cache data live under the XDG cache directory.
- The Rust user service is the sole writer of portable configuration.
- Settings and `qs-config` send mutations/imports to the service. Direct human edits are watched and validated as complete documents.
- Apply only a fully parsed, fully validated snapshot. On failure, retain the last-known-good snapshot and report the error in settings and logs.
- Seed packaged defaults only when the portable configuration is absent. Rebuilds never overwrite user edits.

### Schema and migration

- The portable document has an explicit schema version.
- Automatically migrate known older schemas forward after writing a timestamped backup.
- The shell may read known older versions but never rewrites them itself.
- An older binary refuses a newer schema and keeps its last-known-good configuration. It must not ignore unknown semantics or downgrade the file.

### Settings commit behavior

- Ordinary valid setting changes save atomically and live-apply immediately.
- Offer Undo for the last change.
- Complex control-layout edits are transactional with explicit Done and Cancel.
- Provide per-section reset and confirmed global reset; both preview their effects and create recoverable backups as appropriate.

### Import/export

- Settings provides file-picker import/export.
- `qs-config` provides deterministic validate, import, and export operations for dotfiles automation.
- Import validates and migrates, shows a concise change preview, backs up the current configuration, and then replaces it atomically. Do not deep-merge layouts or arrays.
- Default export includes all portable bar, widget, control-layout, theme, behavior, animation, and unit settings.
- Exclude caches, runtime state, Wi-Fi/Bluetooth credentials, device identifiers, and observed monitor state.
- Named weather locations and coordinates are sensitive and excluded by default. A separate explicit “include sensitive location data” export option is off by default.
- Automatic-location fixes always remain machine-local state.
- Neither settings nor CLI commits or pushes Git.

## 4. Visual and motion system

### Direction

- Use a restrained hybrid of Material clarity and macOS glass depth; do not clone either component library.
- The production bar reserves space but draws no full-length bar background. Pills and circles are floating islands on a transparent strip.
- Surfaces are near-opaque by default, with a subtle outline and restrained shadow. Niri blur is optional enhancement; every surface remains legible without compositor blur.

### Initial theme

- Use the longstanding Banff mist wallpaper.
- Initial palette: fog/charcoal surfaces, off-white primary text, muted secondary text, and a warm amber accent sampled from the wallpaper’s road/light tones. Charging, caution, and danger retain separate semantic colors.
- Exact token values are tuned during live screenshot validation and remain editable semantic theme values.
- Ship one configured palette initially. No automatic light/dark mode, wallpaper extraction service, or theme switcher.
- Default UI typeface: IBM Plex Sans with IBM Plex Sans JP/system fallbacks.
- Use tabular figures for the clock. PlemolJP Console NF remains available for monospace surfaces but is not the general UI font.
- Bundle coherent symbolic vectors for shell controls, status, and weather. Resolve app-provided notification icons through the system icon theme.

### Geometry

- Work in Qt logical pixels and respect display scaling.
- One global UI scale multiplies canonical geometry; do not expose unrelated size controls for every widget.
- Initial baseline: 48 px status/notification circles, approximately 40 px clock/weather height, 8 px inter-island gaps, and a 60 px reserved bar strip.
- Attached panels use a common 420 logical-pixel base width, clamped to usable display space.

### Motion

- Default motion is snappy with restrained spring. Use light overshoot only for workspace burst, notification separation/return, and hover growth.
- No continuous decorative animation.
- Baseline values: about 140 ms hover, 180–240 ms standard transitions, 220 ms clock/workspace transitions, 900 ms workspace collapse delay, 1.6 s temporary status dwell, 1.0 s control-ring return, 2.5 s notification media dwell, and 10 s active Bluetooth scan cadence.
- Store timing/easing as semantic per-behavior settings, not an arbitrary animation-property editor.
- Reduced motion follows the detectable system preference with an explicit user override. It removes translation, scaling, spring, ticker roll, ring sweep, and water-drop morph. Preserve state legibility with opacity crossfades of at most 100 ms or immediate updates.

### Accessibility

- All panels and settings support pointer and keyboard operation.
- Provide visible focus, Tab traversal, Enter/Space activation, arrow-key grids/sliders, nested Escape unwinding, tooltips, and screen-reader names where Qt exposes them.
- No action is gesture-only.

## 5. Bar, outputs, and panels

### Placement

- Support top, right, bottom, and left placement.
- Default to the right edge.
- Placement and scale are shared across displays and are portable configuration.
- Orientation maps leading-to-trailing as left-to-right on horizontal bars and top-to-bottom on side bars.

### Per-display composition

- Every active display gets a reserved bar and its display-local workspace indicator.
- Only the compositor-focused display shows the global omni cluster: weather, clock/notifications, and status/control center.
- When focus moves and no panel is open, crossfade the omni cluster between bars; do not animate it through global monitor coordinates.
- An open omni panel pins the sole cluster and panel to its origin display. Focus may move elsewhere, but no second cluster appears. On dismissal, transfer to the currently focused display.
- If the origin display disappears, close its panel and place the cluster on the new focused display.

### Omni cluster

- Default leading-to-trailing order is weather → clock/notifications → status.
- Settings may move weather to the opposite outer side. Clock/notifications remain one unit; status remains the other core unit.
- Center the entire cluster bounding box. The clock is allowed to shift when notification or hover geometry changes.
- The notification circle inserts between clock and status.
- Under space pressure, first compact weather, then hide weather. Preserve clock, status, and workspaces. Report the automatic weather suppression in settings.
- Workspace and weather widgets may be disabled. Clock/notification anchor and status/control-center entry are core and cannot be disabled initially.

### Panel behavior

- Exactly one omni panel may be open globally: calendar, control center, notifications, or weather.
- A panel visually attaches to its trigger, grows inward from the screen edge, and clamps to that display.
- Opening another replaces the current panel.
- Outside click, Escape, or activating the trigger toggles/dismisses it.
- Nested subpanels consume Escape and Back before the parent panel closes.

## 6. Workspace indicator

### Workspace model

- Configure four persistent Niri workspaces with hidden stable names `ws1`, `ws2`, `ws3`, and `ws4`.
- Present them exclusively as digits 1–4.
- Bind `Super+1` through `Super+4` and matching move-column bindings to the string workspace identities, not dynamic numeric indices.
- Remove `Super+5` through `Super+0` workspace bindings.
- Retarget browser and terminal window rules to `ws1` and `ws2`.
- The four workspaces are one global set and may be distributed among outputs. Each display’s bar marks the configured workspace active on that output.
- Any active dynamic or unexpected workspace is represented as `?`; do not widen the compact indicator, show a stale digit, or expose internal names.

### Interaction

- Display-only. No click, scroll, or pointer workspace switching.
- State comes from the Niri event stream and keyboard/compositor actions.

### Collapsed state

- All four layers converge on the exact same coordinates and remain opaque.
- The active numbered pill is topmost, so only one shape is visible.
- “Stack” describes z-order and the common burst origin. Do not offset layers or use color/transparency to reveal a card stack.
- On startup/reload, query current state and appear correctly collapsed without a synthetic animation.

### Expanded state

- On a real workspace change, four workspace shapes burst from the common center into stable positions ordered 1→4 leading-to-trailing.
- No numbers appear while expanded.
- The active workspace is a longer pill; inactive workspaces are dots. Previous and next states morph directly between dot and pill.
- An unexpected active workspace adds a transient trailing `?` pill while expanded, then collapses to `?`.
- If another switch arrives while expanded, stay expanded, retarget the pill from its current visual state, and reset the collapse timer. Never queue stale transitions or replay the burst.
- After the configurable delay, all shapes animate back to the common center and reveal the numbered active pill.

## 7. Clock and calendar

### Compact clock

- Always render time in a pill.
- Default to `HH:mm`, 24-hour, without seconds.
- Support 12-hour mode. English uses locale-natural `h:mm AM/PM`; Japanese uses `午前/午後 h:mm`. Do not lead-pad the 12-hour hour.
- Animate only changed digits.
- For adjacent forward ticks, old digits move upward and new digits enter from below. Reverse for an adjacent backward correction.
- After suspend or a gap greater than one minute, snap to current time without replaying missed ticks.
- Ticker duration/easing are semantic settings.

### Hover and click

- Hover grows the clock pill inward from the screen edge, retains time, and reveals the locale-formatted full weekday/month/day. It must not push the cluster along the bar axis beyond normal cluster recentering.
- Any click on the clock opens the calendar regardless of hover-animation progress.

### Calendar

- Reset to the actual current month each time it opens.
- Fixed six-week grid; show adjacent-month dates dimmed.
- Highlight today with the accent color when visible.
- Date cells are display-only.
- Week start follows locale by default with Sunday/Monday/Saturday override.
- Previous/next buttons and Left/Right keys navigate one month. Wheel navigation is disabled.
- Month title opens a localized 3×4 month grid and keeps the displayed year.
- Year title opens a scrollable nearby-year list plus direct numeric entry across the supported calendar range and keeps the displayed month.
- Navigation fades and swipes according to chronological direction, including month/year selection.
- Rapid navigation interrupts and retargets from the current visual state; never queue animations or ignore input.
- Outside click, Escape, or clock toggle closes. Escape first closes an open month/year selector.

## 8. Status widget

### Base geometry and ring mapping

- Circular 48 px island with a padded background track and center icon.
- Progress starts at 12 o’clock and advances symmetrically down both sides.
- At 0%, show only the dim background track.
- At 50%, active arcs form the top half/rainbow.
- At 80%, the ring is mostly closed with a downward-facing gap.
- At 100%, the active ring is complete.
- Use rounded endpoints and animate percentage changes through the symmetric geometry.

### Persistent state

- Center icon network precedence: Ethernet with connectivity → connected Wi-Fi with signal band → enabled/disconnected Wi-Fi → offline/slashed network.
- Wi-Fi uses four bands with hysteresis to prevent threshold flicker.
- Battery uses the UPower display-device aggregate, with highest-design-capacity internal battery fallback.
- Below 20%, the battery ring transitions to configurable danger red.
- While charging, charging accent overrides the low-battery warning color.
- On machines without a battery, retain a dim neutral track; control feedback grows from and returns to it.

### Temporary indicator priority

Highest to lowest:

1. Bluetooth device connected.
2. External power connected.
3. Direct user-control feedback: output volume, microphone/input level, or brightness. Latest control action wins within this class.
4. Media event.
5. Persistent network.

- Higher-priority events preempt lower ones.
- Blocked/preempted events are dropped, not queued or resumed later.
- Latest event at the same priority resets its timer.
- Volume/input/brightness always own the ring during their activity even if a higher-priority Bluetooth or power icon remains visible.

### User-control feedback

- Output volume is clamped to 0–100%. Show speaker/mute icon and a visibly lighter volume ring.
- Microphone changes show mic/slashed-mic and input-level ring.
- Brightness changes show a sun icon and brightness ring for the controllable originating display.
- Actual PipeWire changes drive output/input feedback even when initiated by direct `wpctl` keybindings.
- Route media and brightness keybindings through QS/backend commands so direction and display target are known.
- Each control change resets one configurable control-feedback delay. Icon and ring return together after inactivity.

### Media

- Media state is temporary after playback-state or track events; it does not permanently replace network.
- Play glyph means resulting state is playing; pause glyph means resulting state is paused.
- Select the playing MPRIS player, then the most recently active player if none plays.
- Niri next/previous/play-pause bindings route through shell IPC, which forwards to MPRIS and knows navigation direction.
- Next enters right-to-left; previous reverses it.
- Unsolicited metadata changes use a neutral fade because direction cannot be inferred reliably.

### Pointer behavior

- Hover applies a configurable visual scale around the circle center without changing layout geometry, hit target, or neighboring positions.
- Click opens the control center.

## 9. Control center

### Panel and grid

- Four-column grid. Widths are fixed spans: 25%, 50%, or 100% (1, 2, or 4 columns).
- Pack controls row-major in configured order; capability-hidden controls disappear and remaining controls pack forward.
- Shared base layout across machines/displays; automatic capability filtering only. No force-show/hide overrides initially.
- Controls scroll when needed. Pencil/settings footer remains pinned.
- A narrow slider tile shows icon, value, and a short directly draggable track.
- Clicking tile padding outside the icon/track replaces the whole control-center body with a full-width subpanel/control.
- Header Back, Escape, or activating the originating control returns to the grid. Outside click closes the whole control center.

Default order and widths:

1. Wi-Fi — 50%
2. Bluetooth — 50%
3. Output volume — 100%
4. Input volume — 100%
5. Brightness — 100%, capability-gated
6. Hardware monitor — 50%
7. Fans — 50%, capability/policy-gated

All capable controls appear in the first version. Adding/removing/hiding controls is deferred.

### Wi-Fi

- Icon click toggles Wi-Fi.
- Body click opens the picker. If disabled, show a disabled subpanel with an explicit Enable action; do not implicitly enable from a body click.
- Scan only while the picker is open.
- Group access points by SSID plus security type and represent the strongest AP; let NetworkManager handle roaming.
- Order active, saved, then other networks by signal.
- Support scan, connect, disconnect, open networks, and WPA2/WPA3 personal credentials.
- New credentials are remembered by default with a checked option for a session-only connection.
- Existing saved enterprise profiles may reconnect. Creating new 802.1X profiles, hidden-network editing, forgetting, static IP, and a full connection editor are deferred.

### Bluetooth

- Icon click toggles the adapter.
- Body click opens the picker or a disabled panel with Enable action.
- Scan immediately and then at the configured cadence only while the picker is open.
- Order connected, paired, then discovered devices.
- Support discover, BlueZ confirmation/PIN/passkey agent prompts, pair, trust, connect, and disconnect.
- Successful user-confirmed pairing trusts and attempts to connect the device.
- Rename/remove/full profile management is deferred.

### Audio

- Output and input icons toggle mute.
- Sliders control the selected default PipeWire devices.
- Output/input pickers list available devices and switch the default.
- Defer profiles, ports, per-device volume, per-app streams, and full routing.

### Brightness

- Show only when the bar’s originating display maps to a writable kernel backlight.
- Slider controls that display.
- No picker or body action at 100% width.
- DDC/CI and broadcasting one value to all displays are deferred.

### Hardware monitor

- Compact tile shows total CPU and memory percentages.
- Opening replaces the control-center body with live detail.
- Sample CPU/GPU/memory/fans about once per second and storage about every five seconds only while the panel is open.
- Show CPU utilization and available temperatures.
- Compact GPU summary uses the compositor/render GPU. Detail lists every detected GPU with only grounded supported metrics: utilization, used/total memory, and temperature.
- Omit unsupported metric rows; never estimate. A capability note may explain absence.
- Show memory used/total/percentage.
- Temperatures are always Celsius.
- Storage is device-centric: each attached local physical SSD/NVMe/USB device counts once, with mounted filesystems and used/total nested beneath it. Unmounted removable devices remain listed as connected. Each mounted network share counts once. Exclude pseudo filesystems, loop devices, overlay/bind duplicates, tmpfs, and Nix-store-style read-only noise.

### Fans and safety

- Show only headers explicitly exposed by per-host Nix safety policy and currently populated/configurable.
- Never expose non-configurable GPU fans or raw sysfs paths.
- UI provides per-fan Auto toggle, 0–100% PWM slider, and measured RPM.
- The privileged helper validates hardware-specific ranges and minimums.
- Manual mode is runtime-only and starts in Auto after login/restart.
- Manual control requires a renewable shell-client lease. Loss of shell connection, malformed input, helper restart, logout, or lease timeout restores every controlled header to firmware Auto or maximum-safe behavior.
- Recommended initial lease is five seconds, renewed every two seconds.
- Host policy declares stable hwmon identity/channel allowlists, safe minimums, and warning/critical thermal sensors.
- Invalid/missing sensor readings or critical thresholds revoke manual control and force Auto/maximum-safe cooling.
- Expose the helper through a constrained system D-Bus API with polkit authorization for the active local user. Never run the entire user backend as root.

### Editing

- Pencil enters a transaction over the current layout.
- Drag the whole tile; show a live insertion placeholder and reflow peers.
- Resize using a visible trailing-edge handle snapping to 25/50/100, with an accessible size menu on activation.
- Footer becomes Cancel and Done. Cancel restores the entry snapshot; Done atomically persists.
- Settings exposes a structured list/grid editor over the same model with keyboard reorder and explicit width selectors.

## 10. Notifications

### Ownership and lifetime

- Quickshell owns `org.freedesktop.Notifications`; no second notification daemon runs.
- Track active notifications only. No grouping or history initially.
- Honor explicit positive application timeouts and explicit persistent timeout.
- Daemon defaults: low urgency six seconds, normal urgency twelve seconds, critical persistent.
- Pause all expiry while the panel is open and pause an individual row while hovered/focused; resume remaining duration afterward.
- A shell crash restarts with an empty active set. Do not persist stale display snapshots or invalid action handles.
- No DND in the first version.

### Circle behavior

- No conventional toast popups initially. Arrival feedback is the water-drop circle only.
- When the first active notification arrives, separate a 48 px circle from the clock toward the status side with a water-drop animation.
- Keep it visible while active notifications exist.
- Prefer notification image data/path, then app-provided icon through the theme, then a generic notification symbol.
- Show the most recent active notification’s media for the configured 2.5-second delay, then show active count capped visually at `99+`.
- A new notification transitions to its media immediately and resets the delay. Do not queue all arrivals.
- If the newest notification is dismissed, transition to the next newest media and reset the delay.
- Critical media/count uses a semantic danger outline but does not reorder the list.
- Clearing/dismissing the final notification returns the circle into the clock with coordinated cluster motion.

### Panel

- Clicking the circle opens the notification panel and replaces the circle position with an X/close control.
- X collapses the panel back into the circle.
- Most recent first.
- Size for five standard rows when space permits; clamp and scroll sooner for tall content or small displays.
- Pin Clear all at the bottom. It attempts to dismiss every dismissible notification, including critical/persistent entries; failures remain visible.
- Title is one line and body is up to three lines in collapsed rows. A disclosure affordance expands long content in place.
- If a default action exists, body click invokes it. Without a default action, body click does nothing.
- Render named action buttons and individual dismiss controls.
- Inline reply is deferred.

## 11. Weather

### Provider and refresh

- Use Open-Meteo behind a provider interface.
- Refresh on startup, on panel open if stale, and every 15 minutes while the shell runs.
- Back off on errors and retain the last successful payload.
- Data becomes stale after 30 minutes without a successful refresh.
- Required attribution appears as a subtle linked `Weather data: Open-Meteo` footer in the expanded panel, not the compact widget.

### Location

- Default to Automatic location through GeoClue with explicit system permission. Never use IP geolocation.
- If permission/location is unavailable, keep using the last or selected configured location and clearly report that Automatic needs permission.
- Settings manages unlimited named fixed locations using geocoding results with city/region/country disambiguation.
- In the weather panel, the location header is a dropdown listing Automatic and saved locations. A Manage Locations entry opens the settings location page.
- Adding/editing/removing locations occurs only in settings.
- Forecast times and sunrise/sunset use the selected location’s timezone; the shell clock continues to use device timezone.

### Units

- Use one explicit preset rather than per-category overrides.
- Default Imperial: °F, mph, inHg, and inches.
- Metric: °C, km/h, hPa, and millimeters.

### Compact widget

- Normal state shows current temperature and bundled condition icon.
- Support clear/sunny, cloud/overcast, rain, hail, thunderstorm, snow, wind, and fog mappings.
- Hover may reveal location and daily high/low.
- Any click opens the panel, independent of hover progress.
- After 30 minutes stale, replace compact data with a small `–` state. Opening still shows the last successful forecast, timestamp, and error/stale indication.
- Under bar space pressure, compact and then hide weather as defined in the bar rules.

### Expanded panel

- Clean, condensed layout with selected location, current temperature/condition, high/low, and last update state.
- Horizontally scrollable next-24-hours strip beginning with the current hour.
- Vertically compact ten-day rows containing day, condition, precipitation probability, low/high, and temperature-range bar.
- Include wind speed/direction, precipitation probability and amount, sunrise/sunset, and pressure.
- The forecast content scrolls while current conditions/header remain usable.
- There is no external Open Weather action or separate weather application.

### Approaching-condition alerts

- Enabled by default for the active location only.
- Detect dry→rain/snow/hail/thunder and wet→dry transitions predicted within the next 60 minutes.
- Emit one normal shell notification per predicted transition. Update only when timing changes materially; do not regenerate from stale data.
- Compact weather may retain a subtle warning state until the transition passes.
- Saved but inactive locations do not notify.

## 12. Settings application

- Separate Quickshell package/process with the same design tokens as the shell.
- Singleton window. Activating a gear while open raises it and moves it to the originating display while preserving the current page.
- Gear appears in the pinned control-center footer and opens settings; operational pickers never open settings.
- Scope: bar placement/scale, top-level widget visibility/order constraints, control layout/order/width, semantic palette and surface appearance, clock/date, weather locations and units, behavior, notification defaults, and semantic animation/reduced-motion values.
- The settings app does not configure Wi-Fi profiles, Bluetooth devices, audio routing, brightness hardware, storage, or fan safety policy.
- Capability detection is automatic only in the first version.
- Live save/undo, reset, import/export, migrations, and structured layout editing follow the configuration contracts above.

## 13. Explicit non-goals

Do not invent extension points or partial implementations for these items:

- Hyprland or another compositor backend.
- Desktop-host validation during the MacBook-first build.
- Dynamic wallpaper changes, wallpaper-derived live themes, multiple named theme profiles, automatic light/dark switching, or a theme switcher.
- Auto-hide/overlay bar modes or per-display placement profiles.
- Touch-only gestures.
- Workspace pointer interaction or more than four configured workspace identities.
- Control-center tile add/remove/hide.
- Wi-Fi enterprise-profile creation, hidden-network/full connection editing, static IP, and forget/edit flows.
- Bluetooth rename/remove/full profile management.
- Full audio routing, per-app streams, or per-device volume surfaces.
- External-display DDC/CI brightness.
- Notification grouping, persistent history, DND, conventional toasts, or inline reply.
- Weather for inactive saved locations, external weather applications, or severe-weather rule engines beyond approaching precipitation transitions.
- Date-cell actions.
- Persistent manual fan values.
