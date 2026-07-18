extends Node

# GD_ArcadeLauncher's GAME_SPEC.md requires every game to quit immediately
# on the ui_exit action so players can return to the launcher.
# Cabinet: Select button (left bank, raw button index 8). Keyboard: F10.

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_exit"):
		get_tree().quit()
