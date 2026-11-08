extends Node
## 探针：窄房间里"直冲"和"反弹一次"分别能不能撞碎裂纹墙。
##   godot --headless --path . res://tools/probe_bounce.tscn

var _first_stage := -1

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	for mode in ["straight", "bounce"]:
		await _run_mode(mode)
	get_tree().quit()

func _run_mode(mode: String) -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Save.clear()
	var chapter: Chapter = (load("res://scenes/levels/ch3_crack.tscn") as PackedScene).instantiate()
	add_child(chapter)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	while player.state != Player.State.ACTIVE:
		await get_tree().physics_frame
	var wall: CrackedWall = null
	for node in chapter.find_children("*", "Node2D", true, false):
		if node is CrackedWall:
			wall = node as CrackedWall
			break
	if wall == null:
		print("BOUNCE 没有裂纹墙")
		return
	# 站进窄房间：离裂纹墙 6 格（刚好是直冲距离）
	player.global_position = wall.global_position - Vector2(6 * 32, 32)
	player.velocity = Vector2(500.0, 0.0)
	player.stage = 3
	_first_stage = -1
	var top := 3
	var hit_stage := -1
	Input.action_press("move_right")
	for i in 300:
		await get_tree().physics_frame
		top = maxi(top, player.stage)
		if hit_stage < 0 and is_instance_valid(wall) and player.global_position.x > wall.global_position.x - 40.0:
			hit_stage = player.stage
		if not is_instance_valid(wall):
			break
	print("BOUNCE [%s] 第一次到墙前阶段=%d 最高阶段=%d 墙碎=%s" % [
		mode, hit_stage, top, not is_instance_valid(wall)])
	Input.action_release("move_right")
	chapter.queue_free()
	await get_tree().process_frame
