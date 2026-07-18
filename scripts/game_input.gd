extends Node

# Autoloaded input configuration (GameInput, from scenes/game_input.tscn).
# Owns everything input-related:
# - Installs an SDL mapping so the CY-1121 cabinet's two unrecognized
#   "Twin USB" banks present as standard gamepads (panel buttons
#   1-6 = A/B/X/Y/LB/RB, Start = start, Select = back). The GUID is read
#   from the connected device because SDL GUIDs differ between Windows
#   (dev) and Linux (cabinet), and the name prefix is matched loosely
#   because the OS-reported name differs too ("Twin USB Gamepad" on
#   Windows, "Twin USB Joystick" on Linux).
# - Assigns joypads to players dynamically: the two lowest connected
#   device ids drive p1_* and p2_* (project.godot's hardcoded 0/1 are
#   just placeholders). Enumeration order is not guaranteed, so
#   swap_player_devices flips which bank is which.
# - map_all_inputs_to_p1: single-player convenience — every control drives p1_*.
# - Quits immediately on ui_exit, as GD_ArcadeLauncher's GAME_SPEC.md
#   requires (Select on the cabinet, Back/View on a pad, F10 on keyboard).

const CABINET_PAD_PREFIX := "Twin USB"
const CABINET_LAYOUT := "a:b0,b:b1,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,back:b8,start:b9,leftx:a0,lefty:a1,dpup:h0.1,dpright:h0.2,dpdown:h0.4,dpleft:h0.8"

## Map All Inputs to P1 — when enabled, the joypad bindings of every p1_*
## action match any device, and every p2_* binding (keyboard and joypad) is
## rerouted onto the matching p1_* action, so all controls drive Player 1
## and the p2_* actions go silent.
## Can also be toggled at runtime via GameInput.map_all_inputs_to_p1.
@export var map_all_inputs_to_p1 := false: set = set_map_all_inputs_to_p1

## Swap which physical joypad drives P1 vs P2. The cabinet's two banks can
## enumerate in either order (on some machines the right bank comes first),
## so flip this if the sides come out reversed.
## Can also be toggled at runtime via GameInput.swap_player_devices.
@export var swap_player_devices := false: set = set_swap_player_devices

# Device ids currently driving each player's joypad bindings (read-only;
# managed by _reassign_devices). A player whose device id has no connected
# pad simply receives no joypad input.
var p1_device := 0
var p2_device := 1

var _p2_moved_events: Dictionary = {}  # p2 action StringName -> its InputEvents, now living on the p1 twin

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for device in Input.get_connected_joypads():
		_map_if_cabinet_pad(device)
	_reassign_devices()
	if map_all_inputs_to_p1:
		_apply_pooling()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_exit"):
		get_tree().quit()

func set_map_all_inputs_to_p1(value: bool) -> void:
	if map_all_inputs_to_p1 == value:
		return
	map_all_inputs_to_p1 = value
	if not is_node_ready():
		return  # _ready applies the initial value
	if value:
		_apply_pooling()
	else:
		_revert_pooling()

func set_swap_player_devices(value: bool) -> void:
	if swap_player_devices == value:
		return
	swap_player_devices = value
	if not is_node_ready():
		return  # _ready applies the initial value
	_reassign_devices()

func _reassign_devices() -> void:
	var pads := Input.get_connected_joypads()
	pads.sort()
	var first: int = pads[0] if pads.size() >= 1 else 0
	var second: int = pads[1] if pads.size() >= 2 else first + 1
	p1_device = second if swap_player_devices else first
	p2_device = first if swap_player_devices else second
	_apply_device_assignment()

func _apply_device_assignment() -> void:
	# Rewrites the device field of every p1_*/p2_* joypad binding. GameInput
	# owns those fields — the ids in project.godot are only placeholders.
	# While pooled, p1_* is left untouched: its joypad events stay at -1.
	for action in InputMap.get_actions():
		var action_name := String(action)
		var device: int
		if action_name.begins_with("p1_") and not map_all_inputs_to_p1:
			device = p1_device
		elif action_name.begins_with("p2_"):
			device = p2_device
		else:
			continue
		for event in InputMap.action_get_events(action):
			if _is_joypad_event(event):
				event.device = device
	_release_player_actions()

func _apply_pooling() -> void:
	for action in InputMap.get_actions():
		if String(action).begins_with("p1_"):
			for event in InputMap.action_get_events(action):
				if _is_joypad_event(event):
					event.device = -1
	# Only p2's keyboard events actually move onto the p1 twin — p1's own
	# joypad events at device -1 already cover every pad, and InputMap
	# treats -1 as a wildcard when matching duplicates, so a moved p2 joypad
	# event could neither be added nor later erased reliably. p2's joypad
	# events are just parked in _p2_moved_events until the revert.
	for action in InputMap.get_actions():
		var action_name := String(action)
		if not action_name.begins_with("p2_"):
			continue
		var target := StringName("p1_" + action_name.substr(3))
		if not InputMap.has_action(target):
			continue
		var moved: Array[InputEvent] = []
		moved.assign(InputMap.action_get_events(action))
		for event in moved:
			InputMap.action_erase_event(action, event)
			if not _is_joypad_event(event):
				InputMap.action_add_event(target, event)
		if not moved.is_empty():
			_p2_moved_events[action] = moved
	_release_player_actions()

func _revert_pooling() -> void:
	for action in _p2_moved_events:
		var target := StringName("p1_" + String(action).substr(3))
		for event in _p2_moved_events[action]:
			if not _is_joypad_event(event):
				InputMap.action_erase_event(target, event)
			InputMap.action_add_event(action, event)
	_p2_moved_events.clear()
	# Restores per-player devices on everything, including the joypad events
	# that just returned to their p2_* homes.
	_apply_device_assignment()

func _release_player_actions() -> void:
	# The bindings just changed, so pressed state captured under the old
	# bindings can never see its matching release event — without this, a
	# control held across the toggle stays stuck pressed forever.
	for action in InputMap.get_actions():
		var action_name := String(action)
		if action_name.begins_with("p1_") or action_name.begins_with("p2_"):
			Input.action_release(action)

func _is_joypad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_map_if_cabinet_pad(device)
	_reassign_devices()

func _map_if_cabinet_pad(device: int) -> void:
	var joy_name := Input.get_joy_name(device)
	if not joy_name.begins_with(CABINET_PAD_PREFIX):
		return
	var guid := Input.get_joy_guid(device)
	if guid.is_empty():
		return
	Input.add_joy_mapping("%s,%s,%s" % [guid, joy_name, CABINET_LAYOUT], true)
