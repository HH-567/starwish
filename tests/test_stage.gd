extends Node
## 关卡节奏探针：从出生点开到出口，记下最高到过几档。
## 序章要尽量压在阶段 2（阈值 470），别的章不该一上来就到阶段 5。
##   godot --headless --path . --fixed-fps 60 res://tests/test_stage.tscn

const MAX_SECONDS := 90.0

var _failures := 0

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	for chapter: Array in Game.chapters:
		await _run(String(chapter[0]), String(chapter[1]))
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _run(id: String, path: String) -> void:
	Save.clear()
	var chapter := (load(path) as PackedScene).instantiate() as Chapter
	add_child(chapter)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	while player.state != Player.State.ACTIVE:
		await get_tree().physics_frame
	var level := chapter.get_node(^"Level") as Node2D
	var walls := level.get_node(^"Walls") as TileMapLayer
	var start := walls.local_to_map(walls.to_local(player.global_position))
	var exit := _exit_cell(level)
	if exit == Vector2i(-1, -1):
		_check("%s：找得到出口" % id, false)
		chapter.queue_free()
		return
	var route := _path(walls, start, exit)
	if route.size() <= 2:
		# 靠虫洞过墙的章节（ch2）：从另一头再算一次
		for node in level.find_children("*", "Wormhole", true, false):
			var b := (node as Wormhole).get_node(^"B") as Node2D
			var part := _path(walls, walls.local_to_map(walls.to_local(b.global_position)), exit)
			if part.size() > 2:
				route = part
				start = walls.local_to_map(walls.to_local(b.global_position))
				break
	_check("%s：能从出生点走到出口" % id, route.size() > 2, "%d 格" % route.size())
	if route.size() <= 2:
		chapter.queue_free()
		return
	var points: Array[Vector2] = []
	for i in range(0, route.size(), 3):
		points.append(walls.to_global(walls.map_to_local(route[i])))
	points.append(walls.to_global(walls.map_to_local(exit)))

	var top := 1
	Input.action_press("move_right")
	for i in int(MAX_SECONDS * 60.0):
		await get_tree().physics_frame
		if player.state != Player.State.ACTIVE:
			continue
		top = maxi(top, player.stage)
		if points.is_empty():
			break
		while points.size() > 1 and (player.global_position.distance_to(points[0]) < 48.0 or points[0].x < player.global_position.x - 16.0):
			points.pop_front()
		var target := points[0]
		var dx := target.x - player.global_position.x
		var dy := target.y - player.global_position.y
		var corner := absf(dy) > 40.0 and absf(dx) < 90.0
		_press(&"move_right", dx > 6.0 and not corner)
		_press(&"move_left", dx < -6.0 and not corner)
		_press(&"move_up", dy < -20.0)
		_press(&"move_down", dy > 20.0)
		if points.size() == 1 and player.global_position.distance_to(points[0]) < 80.0:
			break
	for action in [&"move_right", &"move_left", &"move_up", &"move_down"]:
		Input.action_release(action)
	print("STAGE_TOP %s %d" % [id, top])
	if id == "ch0":
		_check("序章最多到阶段 2", top <= 2, "到过阶段 %d" % top)
	else:
		_check("%s：不会一上来就到阶段 5" % id, top <= 4, "到过阶段 %d" % top)
	chapter.queue_free()
	await get_tree().physics_frame

func _exit_cell(level: Node2D) -> Vector2i:
	for node in level.find_children("*", "Exit", true, false):
		var walls := level.get_node(^"Walls") as TileMapLayer
		return walls.local_to_map(walls.to_local((node as Node2D).global_position))
	return Vector2i(-1, -1)

func _press(action: StringName, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _path(walls: TileMapLayer, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var solid := {}
	for cell in walls.get_used_cells():
		solid[cell] = true
	var used := walls.get_used_rect()
	var came := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if cell == goal:
			var out: Array[Vector2i] = []
			var at := goal
			while at != start:
				out.push_front(at)
				at = came[at]
			return out
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + d
			if not used.has_point(next) or solid.has(next) or came.has(next):
				continue
			came[next] = cell
			queue.append(next)
	return []

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
