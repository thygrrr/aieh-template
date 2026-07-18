# AIEH Template

Godot template preconfigured for the CY-1121 arcade cabinet and the
[GD_ArcadeLauncher](https://github.com/thygrrr/GD_ArcadeLauncher) upload spec.

## Input map

All actions live in the project Input Map (Project Settings → Input Map).
Joypad bindings use standard (SDL semantic) button indices, so any ordinary
gamepad works out of the box for local development. The CY-1121 panel
enumerates as two unrecognized "Twin USB" devices ("Twin USB Gamepad" on
Windows, "Twin USB Joystick" on Linux); the `GameInput` autoload
(`scenes/game_input.tscn`) installs an SDL mapping for them at runtime so
both banks also present as standard gamepads — one binding set serves
cabinet and desktop.

`GameInput` is the single home for input behavior: the cabinet mapping shim,
the `ui_exit` instant quit, the pause overlay (below), dynamic player-device
assignment (below), and a
**`map_all_inputs_to_p1`** boolean (open
`scenes/game_input.tscn` and toggle "Map All Inputs To P1" in the Inspector,
or set `GameInput.map_all_inputs_to_p1` at runtime). When enabled, all
controls drive the `p1_*` actions — handy for single-player games: `p1_*`
joypad bindings match any device, and every `p2_*` binding (keyboard and
joypad) is rerouted onto its matching `p1_*` action, leaving the `p2_*`
actions silent. Toggling it releases all `p1_*`/`p2_*` pressed states, so
players re-press after a swap.

The physical panel is documented in `button-layout.svg` (corrected
2026-07-18; labels are `b<raw button>_<player>`; `button-layout.jpg` is the
older photo it supersedes). Each bank has a stick and six colored buttons
lettered on the panel: **A** yellow, **B** orange, **C** red, **D** purple,
plus blue and green. Between the banks sit two white Start buttons (marked
with volume icons — the launcher uses them for volume) and one black button.

| Action | Cabinet | Gamepad (Xbox / DualShock) | Keyboard |
|---|---|---|---|
| `p1_left/right/up/down` | Left bank stick | Left stick + D-pad (device 0) | Arrow keys |
| `p1_button1`–`p1_button4` | Left A / B / C / D (yellow/orange/red/purple) | A / B / X / Y (Cross/Circle/Square/Triangle) | Z X C V |
| `p1_button5`, `p1_button6` | Left blue / green | LB / RB (L1 / R1) | B N |
| `p1_start` | Left white center button | Start / Options | 1 |
| `p2_*` | Right bank (same layout); start = right white center button | Same, device 1 | A D W S move, U I O J K L buttons, 2 start |
| `ui_exit` | Black center button | Back / View / Share (any device) | F10 |

Notes:

- **The white Start buttons are NOT wired crosswise**: per
  `button-layout.svg` (corrected 2026-07-18), each white button reports `b9`
  on its own player's device (left = P1, right = P2), so `p1_start` and
  `p2_start` bind straight to their own player's device. Set
  `force_cross_start_devices` (exported on `scenes/game_input.tscn`) only for
  hardware that *is* wired crosswise.
- `GameInput` assigns joypads to players dynamically (it rewrites the device
  field of every `p1_*`/`p2_*` joypad binding — the ids in `project.godot`
  are placeholders). Default: lowest device id = P1. **The cabinet's USB
  enumeration is swapped relative to player order** (`button-layout.svg`:
  P1 = device 1, P2 = device 0), so whenever a cabinet ("Twin USB") pad is
  connected the reversed order is applied automatically. If the sides still
  come out reversed, set **`swap_player_devices`** (exported on
  `scenes/game_input.tscn`, or `GameInput.swap_player_devices` at runtime) —
  it flips whichever default applies. Run the controller-test scene to see
  which bank is which.
- The cabinet sticks are digital (axes report ±1.0), so the 0.2 deadzone
  always triggers cleanly.
- `GameInput` reads each pad's GUID at runtime instead of hardcoding one,
  because SDL GUIDs differ between Windows (dev) and Linux (cabinet).
- `ui_up/down/left/right`, `ui_accept`, `ui_cancel` are explicitly overridden
  so both players feed them equally: joypad events match any device (stick +
  D-pad navigate, A/Button 1 = accept, B/Button 2 = cancel, per the launcher
  spec), and both keyboard sets work (arrows and WASD navigate; Enter, Space,
  Z, U accept; Escape, X, I cancel).

## Pause overlay

`GameInput` ships a built-in pause: pressing **Start** (either white cabinet
button, Start on a pad, or keys 1/2) pauses the scene tree and shows a
"PAUSED — Hold pause button for 3 seconds to quit — tap to continue" overlay.
While it is up, tapping a Start button resumes; holding one for 3 seconds
quits (a live countdown replaces the hint). The press that opened the overlay
counts too, so simply holding Start for 3 seconds quits from anywhere in a
game. `ui_exit` still quits instantly, independent of the overlay, as the
launcher spec requires.

Games that implement their own pause menu can turn this off via the exported
**`pause_overlay_enabled`** boolean on `scenes/game_input.tscn` (or
`GameInput.pause_overlay_enabled` at runtime). The overlay also stands down
if something else paused the tree, and a scene can consume Start events
before they go unhandled to keep the overlay from opening. The raw input
debug scene disables it outright.

## Controller test scene

`scenes/controller_test.tscn` (the default main scene) lists every `p1_*` and
`p2_*` action in two columns plus the `ui_*` actions, and highlights each one
in green while it is held. The action grid is purely action-driven, so it
shows exactly what `GameInput`'s configuration produces (including
`map_all_inputs_to_p1`, whose current state is shown in the header alongside
the P1/P2 device assignment). To identify a physical bank, press its controls
and watch which column lights up.

A diagnostics footer shows every connected joypad (device id, name, GUID,
whether a mapping is installed) and traces the most recent joypad events as
Godot delivers them (`device N button M` / `device N axis M ±1.0`). If a bank
misbehaves — wrong side, dead, or merged into the other bank's device — this
readout tells you which device id and button/axis indices its controls
actually emit.

The scene runs in `PROCESS_MODE_ALWAYS`, so when a Start press opens the
pause overlay the action grid keeps updating behind the translucent dim —
you can verify the white Start buttons (which side lights `p1_start` vs
`p2_start`) and the overlay's tap-to-continue / hold-to-quit behavior in the
same place.

Quitting the test scene requires **holding `ui_exit` (Black button / Back / F10) for
3 seconds** — a footer note on screen shows the countdown. The scene consumes
`ui_exit` events so `GameInput`'s instant quit doesn't fire there, letting
you see the action highlight; real gameplay scenes don't intercept it, so
games built on this template still quit immediately as GAME_SPEC.md requires.
Replace `run/main_scene` in `project.godot` when you start building your game.

## Raw input debug scene

`scenes/raw_input_debug.tscn` (point `run/main_scene` at it temporarily when
debugging cabinet wiring) removes every connected joypad's
SDL mapping at startup, so Godot delivers raw HID indices. It also disables
`GameInput`'s pause overlay for the session so nothing interferes with raw
readouts. It shows panels
for device ids 0–3 (plus anything else connected) whether or not Godot
reports them — id, name, GUID, `Input.get_joy_info()`, a live `b0`–`b23`
button grid and `a0`–`a9` axis readout polled every frame — plus a log of
the most recent joypad events. Press every physical control and note its
device + index — this is the ground truth the mapped controller-test scene
cannot show, because a mapping silently swallows any index it does not
reference.

On Linux it also renders (and `print()`s, so the launcher log captures it) a
kernel-level view from `/proc/bus/input/devices`: every input device with a
`js` handler, its name/phys/handlers, and whether this process can open each
`/dev/input` node. That distinguishes "the kernel created a second joystick
device Godot cannot read" (a permissions problem) from "the kernel merged
both banks into one device" (the Twin USB adapter without
`HID_QUIRK_MULTI_INPUT` — duplicate controls collapse onto the same event
codes, which shows up as the second stick mirroring the first and the second
bank's buttons vanishing).

Quit with F10/Escape, or hold any single joypad button for 5 seconds. When
debugging is done, point `run/main_scene` in `project.godot` back at
`res://scenes/controller_test.tscn` (the default).

## Cabinet kernel quirk: splitting the merged Twin USB device

The CY-1121 encoder presents both banks through one USB device, and by
default the Linux kernel merges them into a single input device — the
symptom is one joystick in Godot, both sticks driving P1, and the second
bank's buttons dead. The fix is telling the kernel's HID layer to create a
separate input device per interface (`HID_QUIRK_MULTI_INPUT`, value `0x40`).
This is a one-time OS-level change on the cabinet (Ubuntu), not something the
template can do from inside the game.

1. Confirm the USB ID with `lsusb`. On our cabinet the encoder shows up as:

   ```
   Bus 001 Device 003: ID 0810:e001 Personal Communication Systems, Inc. Twin controller
   ```

2. Edit the kernel command line — `usbhid` is built into the Ubuntu kernel
   (not a module), so a `/etc/modprobe.d/` options file will *not* work; the
   quirk must go on the boot command line via GRUB:

   ```bash
   sudo nano /etc/default/grub
   ```

   Append the quirk inside the existing `GRUB_CMDLINE_LINUX_DEFAULT` quotes
   (space-separated, `0x` prefixes required):

   ```
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash usbhid.quirks=0x0810:0xe001:0x00000040"
   ```

3. Apply and reboot:

   ```bash
   sudo update-grub
   sudo reboot
   ```

4. Verify: `cat /proc/cmdline` should contain the `usbhid.quirks=` string,
   and `/proc/bus/input/devices` should now list **two** "Twin USB" entries,
   each with its own `js` handler. Then run the raw input debug scene — Godot
   should report two devices; per `button-layout.svg` the left (P1) bank
   emits on device 1 and the right (P2) bank on device 0.

(On Raspberry Pi OS the same `usbhid.quirks=...` string goes at the start of
`/boot/cmdline.txt` instead — noted here in case the cabinet hardware ever
changes.)

## GD_ArcadeLauncher conformance

- `ui_exit` is implemented by the `GameInput` autoload
  (`scenes/game_input.tscn`) and quits immediately — mandatory per
  GAME_SPEC.md.
- The project runs fullscreen at 1920×1080 (`canvas_items` stretch, `expand`).
- `game.json` at the project root is the metadata template — edit it and copy
  it into your upload folder.

To ship a game, export for **Linux x86_64** and upload a folder to
`/arcade/games/<your_game>/` containing:

```
game.x86_64 (chmod +x)   # required
game.pck                 # required
game.json                # recommended (edit the one in this repo)
preview.ogv              # recommended, 5–15 s gameplay clip
screenshot.png           # recommended, 1920×1080
icon.png                 # recommended, 128×128
```

## High scores

The `HighScore` autoload (`scripts/high_score.gd`) implements the launcher's
optional score submission spec — call it from anywhere:

```gdscript
if HighScore.is_high_score(score):        # would this make the table?
    var rank := HighScore.submit_score("AAA", score)  # 0 = best, -1 = missed

HighScore.get_scores()   # Array of {"name": ..., "score": ...}, best first
HighScore.get_best()     # top score, 0 if the table is empty
HighScore.clear_scores()
HighScore.scores_changed # signal, emitted after submit/clear — connect UI here
```

The table lives in a `HighScoreData` resource (`scripts/high_score_data.gd`,
an exported array of name/score entries, sorted descending, capped at 10 per
the launcher spec) persisted to `user://high_scores.tres`. It is loaded on
startup and saved on every score change and on application exit (covers both
the `ui_exit` quit and a window close).

At the same times, the table is exported in the launcher's format — a JSON
array of `{"name": "AAA", "score": 10000}` entries — to
`/arcade/scores/<game_id>.json`, where `game_id` is the executable's folder
name under `/arcade/games/` (exactly how the launcher keys scores). On a dev
machine without an `/arcade` directory it falls back to
`user://<game_id>.json` so you can inspect the output; in the editor the
`game_id` falls back to the project name.

`tests/high_score_smoke.gd` is a headless smoke test for all of the above:

```
godot --headless --path . -s res://tests/high_score_smoke.gd
```

`tests/input_smoke.gd` does the same for `GameInput`'s device assignment,
`swap_player_devices`, and the `map_all_inputs_to_p1` round-trip:

```
godot --headless --path . -s res://tests/input_smoke.gd
```
