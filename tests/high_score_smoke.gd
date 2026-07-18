extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var hs: Node = preload("res://scripts/high_score.gd").new()
	root.add_child(hs)
	hs.clear_scores()
	for i in 12:
		hs.submit_score("P%d" % i, i * 100)
	_check(failures, hs.get_scores().size() == 10, "table caps at 10")
	_check(failures, hs.get_best() == 1100, "best is 1100, got %s" % hs.get_best())
	_check(failures, hs.is_high_score(5000), "5000 qualifies")
	_check(failures, not hs.is_high_score(1), "1 does not qualify")
	var rank: int = hs.submit_score("AAA", 99999)
	_check(failures, rank == 0, "AAA is rank 0, got %d" % rank)

	var json_path: String = "/arcade/scores/%s.json" % hs._game_id
	if not FileAccess.file_exists(json_path):
		json_path = "user://%s.json" % hs._game_id
	print("game_id: ", hs._game_id)
	print("json path: ", json_path)
	var f := FileAccess.open(json_path, FileAccess.READ)
	if f == null:
		failures.append("json file missing")
	else:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		_check(failures, typeof(parsed) == TYPE_ARRAY, "json is an array")
		_check(failures, parsed.size() == 10, "json has 10 entries")
		_check(failures, parsed[0]["name"] == "AAA" and int(parsed[0]["score"]) == 99999, "json entry 0 is AAA/99999")
	_check(failures, FileAccess.file_exists("user://high_scores.tres"), "resource saved")

	if failures.is_empty():
		print("SMOKE OK")
	else:
		for msg in failures:
			printerr("FAIL: ", msg)
	quit(0 if failures.is_empty() else 1)


func _check(failures: Array[String], cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
