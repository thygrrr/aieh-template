extends SceneTree

# Headless smoke test for GameInput's device assignment and p1-pooling.
# No joypads exist headless, so assignment falls back to devices 0/1 —
# enough to verify that swap_player_devices and map_all_inputs_to_p1
# rewrite and restore the p1_*/p2_* joypad bindings correctly.


func _initialize() -> void:
	var failures: Array[String] = []
	var gi: Node = preload("res://scripts/game_input.gd").new()
	root.add_child(gi)
	await process_frame  # let gi._ready run — its setters no-op before that

	_check(failures, gi.p1_device == 0 and gi.p2_device == 1,
		"default assignment is 0/1, got %d/%d" % [gi.p1_device, gi.p2_device])
	_check(failures, _joy_devices("p1_button1") == [0], "p1_button1 bound to device 0")
	_check(failures, _joy_devices("p2_button1") == [1], "p2_button1 bound to device 1")

	gi.swap_player_devices = true
	_check(failures, gi.p1_device == 1 and gi.p2_device == 0,
		"swapped assignment is 1/0, got %d/%d" % [gi.p1_device, gi.p2_device])
	_check(failures, _joy_devices("p1_left") == [1, 1], "p1_left rebound to device 1")
	_check(failures, _joy_devices("p2_left") == [0, 0], "p2_left rebound to device 0")

	gi.map_all_inputs_to_p1 = true
	_check(failures, _joy_devices("p1_button1") == [-1],
		"pooled p1_button1 matches any device, got %s" % [_joy_devices("p1_button1")])
	_check(failures, InputMap.action_get_events("p2_button1").is_empty(), "pooled p2_button1 is silent")
	_check(failures, InputMap.action_get_events("p1_button1").size() == 3,
		"pooled p1_button1 gained p2's keyboard event")

	gi.map_all_inputs_to_p1 = false
	_check(failures, _joy_devices("p1_button1") == [1],
		"unpooled p1_button1 back on device 1, got %s" % [_joy_devices("p1_button1")])
	_check(failures, _joy_devices("p2_button1") == [0],
		"unpooled p2_button1 back on device 0, got %s" % [_joy_devices("p2_button1")])

	gi.swap_player_devices = false
	_check(failures, _joy_devices("p1_button1") == [0] and _joy_devices("p2_button1") == [1],
		"unswapped bindings back on devices 0/1, got %s / %s" % [_joy_devices("p1_button1"), _joy_devices("p2_button1")])

	if failures.is_empty():
		print("SMOKE OK")
	else:
		for msg in failures:
			printerr("FAIL: ", msg)
	quit(0 if failures.is_empty() else 1)


func _joy_devices(action: String) -> Array[int]:
	var devices: Array[int] = []
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			devices.append(event.device)
	return devices


func _check(failures: Array[String], ok: bool, what: String) -> void:
	if not ok:
		failures.append(what)
