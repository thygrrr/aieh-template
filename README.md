# AIEH Template

Godot template preconfigured for the CY-1121 arcade cabinet and the
[GD_ArcadeLauncher](https://github.com/thygrrr/GD_ArcadeLauncher) upload spec.

## Cabinet input map

The CY-1121 panel enumerates as **two** USB joypads named "Twin USB Gamepad" —
the left bank is one Godot `device`, the right bank the other. All actions are
defined in the project Input Map (Project Settings → Input Map), with keyboard
fallbacks for desktop testing.

| Action | Cabinet (raw index) | Keyboard fallback |
|---|---|---|
| `p1_left/right/up/down` | Device 0 stick, axis 0 (X) / axis 1 (Y) | Arrow keys |
| `p1_button1`–`p1_button6` | Device 0 buttons 0–5 | Z X C V B N |
| `p1_start` | Device 0 button 9 | 1 |
| `p2_left/right/up/down` | Device 1 stick, axis 0 / axis 1 | A D W S |
| `p2_button1`–`p2_button6` | Device 1 buttons 0–5 | U I O J K L |
| `p2_start` | Device 1 button 9 | 2 |
| `ui_exit` | Any device, button 8 (Select, left bank only) | F10 |

Notes:

- Sticks are digital: axes report ±1.0 or ~0.0, so the 0.2 deadzone always
  triggers cleanly.
- **Enumeration order is not guaranteed.** Player 1 defaults to device 0 and
  player 2 to device 1, but the banks can swap between machines or boots.
  Identify a bank by pressing one of its buttons; for robustness, add a
  "press any LEFT button" screen and rebind at runtime (see the cabinet's
  CONTROLS.md for a snippet).
- `ui_exit` uses device -1 because Select only physically exists on the left
  bank (the right pad's index 8 is an unwired spare terminal).
- Godot's built-in `ui_up/down/left/right`, `ui_accept`, `ui_cancel` defaults
  already match the cabinet: accept = joypad button 0 (panel Button 1),
  cancel = button 1 (panel Button 2), navigation = axes 0/1.

## GD_ArcadeLauncher conformance

- `ui_exit` is implemented by the `ArcadeExit` autoload
  (`scripts/arcade_exit.gd`) and quits immediately — mandatory per GAME_SPEC.md.
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
