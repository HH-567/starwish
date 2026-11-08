extends Node
## 探针：ch3 第一面裂纹墙前的小房间，能不能靠"撞墙反弹"把速度顶到阶段 4 再把墙撞碎。

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
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
		get_tree().quit()
		return
	# 站到墙左边 9 格，给一个阶段 3 的初速（500，阈值 470–620）
	player.global_position = wall.global_position - Vector2(9 * 32, 32)
	player.velocity = Vector2(500.0, 0.0)
	player.stage = 3
	Input.action_press("move_right")
	var top := 3
	var bounces := 0
	for i in 300:
		await get_tree().physics_frame
		top = maxi(top, player.stage)
		if is_instance_valid(wall) == false:
			break
	print("BOUNCE 结果：墙还在=%s 最高阶段=%d 玩家=%.0f" % [is_instance_valid(wall), top, player.global_position.x])
	Input.action_release("move_right")
	# 再单独测一次：从阶段 3 撞软垫会不会被弹飞（不该被弹飞）
	get_tree().quit()
