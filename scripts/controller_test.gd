extends Control

# Live view of every InputMap action: each one lights up while it is held.
# The action grid only polls actions, so it reflects exactly what GameInput's
# configuration (device bindings, pooling) produces. To identify a physical
# bank, press its controls and watch which column lights up.
# A diagnostics footer lists every connected joypad (id, name, GUID, whether
# a mapping is installed) plus GameInput's current P1/P2 device assignment,
# and traces the most recent joypad events (post-mapping, as Godot delivers
# them), so a bank that enumerates unexpectedly — or not at all, or merged
# into another device — is visible on screen.
# ui_exit events are consumed in _input() so GameInput's instant quit never
# fires here; instead the app terminates after holding ui_exit for 3 seconds,
# letting you watch the action highlight without leaving the scene.
# Pressing Start opens GameInput's pause overlay on top of this scene; the
# scene runs in PROCESS_MODE_ALWAYS so the grid keeps updating behind the
# translucent overlay — the start highlights (and the overlay itself) stay
# verifiable in one place.

const ACTION_SUFFIXES: Array[String] = [
	"left", "right", "up", "down",
	"button1", "button2", "button3", "button4", "button5", "button6",
	"start",
]
const UI_ACTIONS: Array[String] = [
	"ui_left", "ui_right", "ui_up", "ui_down",
	"ui_accept", "ui_cancel", "ui_exit",
]

const COLOR_IDLE := Color(0.45, 0.45, 0.45)
const COLOR_PRESSED := Color(0.25, 1.0, 0.35)
const COLOR_EXIT_HOLD := Color(1.0, 0.55, 0.2)

const EXIT_HOLD_SECONDS := 3.0

const EVENT_LOG_LINES := 5

var _labels: Dictionary = {}  # action name -> Label
var _mode_label: Label
var _devices_label: Label
var _event_log_label: Label
var _event_log: PackedStringArray = []
var _exit_label: Label
var _exit_hold := 0.0

func _ready() -> void:
	# Keep polling/highlighting while GameInput's pause overlay has the tree
	# paused, so the Start buttons can be verified live.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 24)
	center.add_child(main)

	var title := Label.new()
	title.text = "Controller Test"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	main.add_child(title)

	_mode_label = Label.new()
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.add_theme_font_size_override("font_size", 20)
	main.add_child(_mode_label)

	var screen_size := DisplayServer.screen_get_size()
	var resolution_label := Label.new()
	resolution_label.text = "Screen resolution: %d x %d" % [screen_size.x, screen_size.y]
	resolution_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resolution_label.add_theme_font_size_override("font_size", 20)
	main.add_child(resolution_label)

	var columns := HBoxContainer.new()
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.add_theme_constant_override("separation", 120)
	main.add_child(columns)
	columns.add_child(_make_column("Player 1", "p1_"))
	columns.add_child(_make_column("Player 2", "p2_"))

	_devices_label = Label.new()
	_devices_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_devices_label.add_theme_font_size_override("font_size", 18)
	main.add_child(_devices_label)

	_event_log_label = Label.new()
	_event_log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_log_label.add_theme_font_size_override("font_size", 18)
	main.add_child(_event_log_label)
	_log_joy_event("(press any joypad control)")

	var ui_row := HBoxContainer.new()
	ui_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ui_row.add_theme_constant_override("separation", 32)
	main.add_child(ui_row)
	for action in UI_ACTIONS:
		ui_row.add_child(_make_action_label(action))

	_exit_label = Label.new()
	_exit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_label.add_theme_font_size_override("font_size", 22)
	main.add_child(_exit_label)

func _input(event: InputEvent) -> void:
	# Keep GameInput's _unhandled_input from quitting instantly in this scene.
	if event.is_action("ui_exit"):
		get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton and event.pressed:
		_log_joy_event("device %d  button %d" % [event.device, event.button_index])
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		_log_joy_event("device %d  axis %d %+.1f" % [event.device, event.axis, event.axis_value])

func _log_joy_event(line: String) -> void:
	if not _event_log.is_empty() and _event_log[_event_log.size() - 1] == line:
		return
	_event_log.append(line)
	while _event_log.size() > EVENT_LOG_LINES:
		_event_log.remove_at(0)
	_event_log_label.text = "recent joypad events:  " + "  |  ".join(_event_log)

func _process(delta: float) -> void:
	if GameInput.map_all_inputs_to_p1:
		_mode_label.text = "Map All Inputs To P1: ON — all controls drive p1_*"
	else:
		_mode_label.text = "Map All Inputs To P1: OFF — P1 = device %d, P2 = device %d%s" % [
			GameInput.p1_device, GameInput.p2_device,
			" (swapped)" if GameInput.swap_player_devices else "",
		]

	var device_lines: PackedStringArray = []
	for device in Input.get_connected_joypads():
		device_lines.append("device %d: %s  guid=%s  %s" % [
			device, Input.get_joy_name(device), Input.get_joy_guid(device),
			"mapped" if Input.is_joy_known(device) else "UNMAPPED",
		])
	if device_lines.is_empty():
		device_lines.append("no joypads connected")
	_devices_label.text = "\n".join(device_lines)

	for action in _labels:
		var label: Label = _labels[action]
		var pressed := Input.is_action_pressed(action)
		label.text = ("[#] " if pressed else "[ ] ") + action
		label.add_theme_color_override("font_color", COLOR_PRESSED if pressed else COLOR_IDLE)

	if not GameInput.ui_exit_enabled:
		# The cabinet's black button is stuck down, so a ui_exit hold would
		# fire on its own — the grid still shows the action, but quitting
		# goes through the pause overlay instead.
		_exit_hold = 0.0
		_exit_label.text = "ui_exit disabled (GameInput.ui_exit_enabled) — hold Start for 3 seconds to quit"
		_exit_label.add_theme_color_override("font_color", COLOR_IDLE)
	elif Input.is_action_pressed("ui_exit"):
		_exit_hold += delta
		if _exit_hold >= EXIT_HOLD_SECONDS:
			get_tree().quit()
			return
		_exit_label.text = "Quitting in %.1f s — keep holding ui_exit" % (EXIT_HOLD_SECONDS - _exit_hold)
		_exit_label.add_theme_color_override("font_color", COLOR_EXIT_HOLD)
	else:
		_exit_hold = 0.0
		_exit_label.text = "Hold ui_exit (Select / Back / F10) for %d seconds to quit" % int(EXIT_HOLD_SECONDS)
		_exit_label.add_theme_color_override("font_color", COLOR_IDLE)

func _make_column(title: String, prefix: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 30)
	column.add_child(header)
	for suffix in ACTION_SUFFIXES:
		column.add_child(_make_action_label(prefix + suffix))
	return column

func _make_action_label(action: String) -> Label:
	var label := Label.new()
	label.text = "[ ] " + action
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", COLOR_IDLE)
	_labels[action] = label
	return label
