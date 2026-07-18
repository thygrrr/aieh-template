# AIEH Template

Godot template preconfigured for the CY-1121 arcade cabinet and the
[GD_ArcadeLauncher](https://github.com/thygrrr/GD_ArcadeLauncher) upload spec.

## Input map

All actions live in the project Input Map (Project Settings → Input Map).
Joypad bindings use standard (SDL semantic) button indices, so any ordinary
gamepad works out of the box for local development. The CY-1121 panel
enumerates as two unrecognized "Twin USB Gamepad" devices; the `GameInput`
autoload (`scenes/game_input.tscn`) installs an SDL mapping for them at
runtime so both banks also present as standard gamepads — one binding set
serves cabinet and desktop.

`GameInput` is the single home for input behavior: the cabinet mapping shim,
the `ui_exit` instant quit, and a **`map_all_inputs_to_p1`** boolean (open
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

- Player 1 = joypad device 0, Player 2 = device 1. **Cabinet bank enumeration
  order is not guaranteed** — the banks can swap between machines or boots.
  Run the controller-test scene to see which bank is which; for full
  robustness add a "press any LEFT button" screen and rebind at runtime (see
  the cabinet's CONTROLS.md).
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
in green while it is held. It is purely action-driven — it knows nothing
about devices, so it shows exactly what `GameInput`'s configuration produces
(including `map_all_inputs_to_p1`, whose current state is shown in the
header). To identify a physical bank, press its controls and watch which
column lights up.

Quitting the test scene requires **holding `ui_exit` (Select / Back / F10) for
3 seconds** — a footer note on screen shows the countdown. The scene consumes
`ui_exit` events so `GameInput`'s instant quit doesn't fire there, letting
you see the action highlight; real gameplay scenes don't intercept it, so
games built on this template still quit immediately as GAME_SPEC.md requires.
Replace `run/main_scene` in `project.godot` when you start building your game.

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

High scores can optionally be written to `/arcade/scores/<folder_name>.json`
as a JSON array of `{"name": "AAA", "score": 10000}` entries (top 10, sorted
descending).
