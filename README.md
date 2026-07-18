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
the `ui_exit` instant quit, dynamic player-device assignment (below), and a
**`map_all_inputs_to_p1`** boolean (open
`scenes/game_input.tscn` and toggle "Map All Inputs To P1" in the Inspector,
or set `GameInput.map_all_inputs_to_p1` at runtime). When enabled, all
controls drive the `p1_*` actions — handy for single-player games: `p1_*`
joypad bindings match any device, and every `p2_*` binding (keyboard and
joypad) is rerouted onto its matching `p1_*` action, leaving the `p2_*`
actions silent. Toggling it releases all `p1_*`/`p2_*` pressed states, so
players re-press after a swap.

| Action | Cabinet | Gamepad (Xbox / DualShock) | Keyboard |
|---|---|---|---|
| `p1_left/right/up/down` | Left bank stick | Left stick + D-pad (device 0) | Arrow keys |
| `p1_button1`–`p1_button4` | Left buttons 1–4 | A / B / X / Y (Cross/Circle/Square/Triangle) | Z X C V |
| `p1_button5`, `p1_button6` | Left buttons 5–6 | LB / RB (L1 / R1) | B N |
| `p1_start` | 1P Start | Start / Options | 1 |
| `p2_*` | Right bank (same layout) | Same, device 1 | A D W S move, U I O J K L buttons, 2 start |
| `ui_exit` | Select (left bank) | Back / View / Share (any device) | F10 |

Notes:

- `GameInput` assigns joypads to players dynamically: the two lowest
  connected device ids drive `p1_*` and `p2_*` (it rewrites the device field
  of every `p1_*`/`p2_*` joypad binding — the ids in `project.godot` are
  placeholders). **Cabinet bank enumeration order is not guaranteed** — if
  the sides come out reversed, set **`swap_player_devices`** (exported on
  `scenes/game_input.tscn`, or `GameInput.swap_player_devices` at runtime).
  Run the controller-test scene to see which bank is which; for full
  robustness add a "press any LEFT button" screen and toggle the swap at
  runtime (see the cabinet's CONTROLS.md).
- The cabinet sticks are digital (axes report ±1.0), so the 0.2 deadzone
  always triggers cleanly.
- `GameInput` reads each pad's GUID at runtime instead of hardcoding one,
  because SDL GUIDs differ between Windows (dev) and Linux (cabinet).
- `ui_up/down/left/right`, `ui_accept`, `ui_cancel` are explicitly overridden
  so both players feed them equally: joypad events match any device (stick +
  D-pad navigate, A/Button 1 = accept, B/Button 2 = cancel, per the launcher
  spec), and both keyboard sets work (arrows and WASD navigate; Enter, Space,
  Z, U accept; Escape, X, I cancel).

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

Quitting the test scene requires **holding `ui_exit` (Select / Back / F10) for
3 seconds** — a footer note on screen shows the countdown. The scene consumes
`ui_exit` events so `GameInput`'s instant quit doesn't fire there, letting
you see the action highlight; real gameplay scenes don't intercept it, so
games built on this template still quit immediately as GAME_SPEC.md requires.
Replace `run/main_scene` in `project.godot` when you start building your game.

## Raw input debug scene

`scenes/raw_input_debug.tscn` (**currently set as the main scene** while the
cabinet's input wiring is being debugged) removes every connected joypad's
SDL mapping at startup, so Godot delivers raw HID indices. It shows panels
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
`res://scenes/controller_test.tscn`.

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
