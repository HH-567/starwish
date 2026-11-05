extends Node
## 测试关冒烟测试：依次加载 test_feel 和 test_light，按住右 2 秒，
## 确认小星跑起来、进过阶段 2、HUD、镜头和各种实体不报错。
##   godot --headless --path . --fixed-fps 60 res://tests/test_level_smoke.tscn

const LEVELS := ["res://scenes/levels/test_feel.tscn", "res://scenes/levels/test_light.tscn"]

func _ready() -> void:
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	var ok := true
	for path in LEVELS:
		var passed: bool = await _run(path)
		ok = ok and passed
	get_tree().quit(0 if ok else 1)

func _run(path: String) -> bool:
	Save.clear()
	var stages := {}
	var on_stage := func(s: int) -> void: stages[s] = true
	Game.speed_stage_changed.connect(on_stage)
	var level := (load(path) as PackedScene).instantiate()
	add_child(level)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var start := player.global_position
	Input.action_press("move_right")
	for i in 120:
		await get_tree().physics_frame
	Input.action_release("move_right")
	var moved := player.global_position.x - start.x
	var ok := moved > 200.0 and stages.has(2)
	print("SMOKE %s %s moved=%.0f stages=%s" % ["PASS" if ok else "FAIL", path.get_file(), moved, stages.keys()])
	Game.speed_stage_changed.disconnect(on_stage)
	level.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	return ok
