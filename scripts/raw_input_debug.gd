extends Control

# Raw joypad debugger: removes every connected joypad's SDL mapping so Godot
# delivers unmapped, raw HID button/axis indices, then renders per device:
# - id, name, GUID and Input.get_joy_info()
# - a live button grid (b0-b23) and axis readout (a0-a9), polled every frame
# - a log of the most recent joypad InputEvents
# Panels are shown for device ids 0-3 (plus anything else connected) whether
# or not Godot reports them connected, so an unopened device cannot hide.
# On Linux a kernel section lists every input device with a js handler from
# /proc/bus/input/devices — name, phys, handlers, and whether this process
# can open each /dev/input node. That distinguishes "the kernel made a second
# device Godot cannot read" (permissions) from "the kernel only made one"
# (missing HID_QUIRK_MULTI_INPUT: duplicate controls merge onto one device).
# The report is also print()ed so it lands in the launcher's log.
#
# Quitting: F10/Escape instantly, or hold any single joypad button for 5 s
# (works even if no mapping and no keyboard is attached).

const BUTTON_COUNT := 24
const AXIS_COUNT := 10
const MIN_PANEL_DEVICES := 4
const EVENT_LOG_LINES := 8
const QUIT_HOLD_SECONDS := 5.0

const COLOR_IDLE := Color(0.45, 0.45, 0.45)
const COLOR_ACTIVE := Color(0.25, 1.0, 0.35)
const COLOR_WARN := Color(1.0, 0.55, 0.2)

var _devices_box: VBoxContainer
var _kernel_label: Label
var _event_log_label: Label
var _quit_label: Label
var _event_log: PackedStringArray = []
# device id -> {buttons: Array[Label], axes: Array[Label]}
var _device_widgets: Dictionary = {}
var _quit_hold := 0.0
var _quit_candidate := Vector2i(-1, -1)  # (device, button) being held

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_strip_mappings()

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 16)
	scroll.add_child(main)

	var title := Label.new()
	title.text = "RAW INPUT DEBUG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	main.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Joypad mappings removed — button/axis indices below are raw.\nPress every physical control and note its device + index."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", COLOR_WARN)
	main.add_child(subtitle)

	_devices_box = VBoxContainer.new()
	_devices_box.add_theme_constant_override("separation", 12)
	main.add_child(_devices_box)

	_kernel_label = Label.new()
	_kernel_label.add_theme_font_size_override("font_size", 14)
	_kernel_label.add_theme_color_override("font_color", COLOR_WARN)
	main.add_child(_kernel_label)
	_refresh_kernel_report()

	_event_log_label = Label.new()
	_event_log_label.add_theme_font_size_override("font_size", 16)
	main.add_child(_event_log_label)
	_log_event("(waiting for joypad events)")

	_quit_label = Label.new()
	_quit_label.add_theme_font_size_override("font_size", 18)
	main.add_child(_quit_label)

	_rebuild_device_panels()

func _input(event: InputEvent) -> void:
	# GameInput quits instantly on ui_exit (F10 / joy button 4) — consume it
	# so a raw button 4 press doesn't kill the debugger mid-session.
	if event.is_action("ui_exit"):
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.physical_keycode in [KEY_F10, KEY_ESCAPE]:
		get_tree().quit()
	if event is InputEventJoypadButton:
		_log_event("device %d  button %d  %s" % [event.device, event.button_index, "pressed" if event.pressed else "released"])
	elif event is InputEventJoypadMotion:
		_log_event("device %d  axis %d  %+.2f" % [event.device, event.axis, event.axis_value])

func _process(delta: float) -> void:
	for device in _device_widgets:
		var widgets: Dictionary = _device_widgets[device]
		for b in BUTTON_COUNT:
			var pressed := Input.is_joy_button_pressed(device, b)
			var label: Label = widgets.buttons[b]
			label.add_theme_color_override("font_color", COLOR_ACTIVE if pressed else COLOR_IDLE)
		for a in AXIS_COUNT:
			var value := Input.get_joy_axis(device, a)
			var label: Label = widgets.axes[a]
			label.text = "a%d %+.2f" % [a, value]
			label.add_theme_color_override("font_color", COLOR_ACTIVE if absf(value) > 0.2 else COLOR_IDLE)
	_update_quit_hold(delta)

func _update_quit_hold(delta: float) -> void:
	var held := Vector2i(-1, -1)
	for device in Input.get_connected_joypads():
		for b in BUTTON_COUNT:
			if Input.is_joy_button_pressed(device, b):
				held = Vector2i(device, b)
				break
		if held.x != -1:
			break
	if held != Vector2i(-1, -1) and held == _quit_candidate:
		_quit_hold += delta
		if _quit_hold >= QUIT_HOLD_SECONDS:
			get_tree().quit()
			return
	else:
		_quit_hold = 0.0
		_quit_candidate = held
	if _quit_hold > 1.0:
		_quit_label.text = "Quitting in %.1f s — keep holding" % (QUIT_HOLD_SECONDS - _quit_hold)
		_quit_label.add_theme_color_override("font_color", COLOR_WARN)
	else:
		_quit_label.text = "Quit: F10 / Escape, or hold any joypad button for %d seconds" % int(QUIT_HOLD_SECONDS)
		_quit_label.add_theme_color_override("font_color", COLOR_IDLE)

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	# GameInput reinstalls the cabinet mapping on reconnect; strip it again.
	_strip_mappings()
	_rebuild_device_panels()
	_refresh_kernel_report()

func _strip_mappings() -> void:
	for device in Input.get_connected_joypads():
		var guid := Input.get_joy_guid(device)
		if not guid.is_empty():
			Input.remove_joy_mapping(guid)

func _rebuild_device_panels() -> void:
	for child in _devices_box.get_children():
		child.queue_free()
	_device_widgets.clear()

	var connected := Input.get_connected_joypads()
	var ids: Array[int] = []
	for device in MIN_PANEL_DEVICES:
		ids.append(device)
	for device in connected:
		if device not in ids:
			ids.append(device)
	ids.sort()

	for device in ids:
		var panel := VBoxContainer.new()
		panel.add_theme_constant_override("separation", 2)
		_devices_box.add_child(panel)

		var header := Label.new()
		if device in connected:
			header.text = "device %d: %s   guid=%s   %s" % [
				device, Input.get_joy_name(device), Input.get_joy_guid(device),
				"STILL MAPPED" if Input.is_joy_known(device) else "raw",
			]
		else:
			header.text = "device %d: (not connected in Godot — polling anyway)" % device
		header.add_theme_font_size_override("font_size", 20)
		panel.add_child(header)

		if device in connected:
			var info := Label.new()
			info.text = "info: %s" % Input.get_joy_info(device)
			info.add_theme_font_size_override("font_size", 13)
			info.add_theme_color_override("font_color", COLOR_IDLE)
			panel.add_child(info)

		var button_row := HBoxContainer.new()
		button_row.add_theme_constant_override("separation", 9)
		panel.add_child(button_row)
		var buttons: Array[Label] = []
		for b in BUTTON_COUNT:
			var bl := Label.new()
			bl.text = "b%d" % b
			bl.add_theme_font_size_override("font_size", 16)
			bl.add_theme_color_override("font_color", COLOR_IDLE)
			button_row.add_child(bl)
			buttons.append(bl)

		var axis_row := HBoxContainer.new()
		axis_row.add_theme_constant_override("separation", 12)
		panel.add_child(axis_row)
		var axes: Array[Label] = []
		for a in AXIS_COUNT:
			var al := Label.new()
			al.text = "a%d +0.00" % a
			al.add_theme_font_size_override("font_size", 16)
			al.add_theme_color_override("font_color", COLOR_IDLE)
			axis_row.add_child(al)
			axes.append(al)

		_device_widgets[device] = {"buttons": buttons, "axes": axes}

func _refresh_kernel_report() -> void:
	var report := _kernel_report()
	_kernel_label.text = report
	print(report)

func _kernel_report() -> String:
	# Linux only: list every kernel input device with a joystick handler and
	# probe whether this process may open its /dev/input nodes.
	if not FileAccess.file_exists("/proc/bus/input/devices"):
		return "kernel view: /proc/bus/input/devices not available (not Linux)"
	var f := FileAccess.open("/proc/bus/input/devices", FileAccess.READ)
	if f == null:
		return "kernel view: cannot read /proc/bus/input/devices (%s)" % error_string(FileAccess.get_open_error())
	var lines: PackedStringArray = ["kernel input devices with a js handler:"]
	for block in f.get_as_text().split("\n\n"):
		var name := ""
		var phys := ""
		var handlers := ""
		for line in block.split("\n"):
			if line.begins_with("N: "):
				name = line.substr(3)
			elif line.begins_with("P: "):
				phys = line.substr(3)
			elif line.begins_with("H: Handlers="):
				handlers = line.substr(12)
		if not handlers.contains("js"):
			continue
		lines.append("  %s   %s" % [name, phys])
		var probes: PackedStringArray = []
		for handler in handlers.strip_edges().split(" "):
			if handler.is_empty() or handler.begins_with("kbd") or handler.begins_with("mouse"):
				continue
			var node := "/dev/input/%s" % handler
			var probe := FileAccess.open(node, FileAccess.READ)
			probes.append("%s %s" % [node, "readable" if probe != null else "OPEN FAILED (%s)" % error_string(FileAccess.get_open_error())])
		lines.append("    " + "   ".join(probes))
	if lines.size() == 1:
		lines.append("  none — the kernel created no joystick device at all")
	return "\n".join(lines)

func _log_event(line: String) -> void:
	if not _event_log.is_empty() and _event_log[_event_log.size() - 1] == line:
		return
	_event_log.append(line)
	while _event_log.size() > EVENT_LOG_LINES:
		_event_log.remove_at(0)
	_event_log_label.text = "recent events (newest last):\n" + "\n".join(_event_log)
