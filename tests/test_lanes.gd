extends Node
## 回程赛道的"跑得通"测试：把每章的赛道单独拿出来，让小星从 Entry 一路跑到 Exit。
## 路点是从赛道图块里算出来的（BFS），不是写死的坐标——这样赛道怎么改都能测。
##   godot --headless --path . --fixed-fps 60 res://tests/test_lanes.tscn
## 拐角多的赛道就是靠这个确认"人能开过去"，光靠连通性检查不够。

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const MAX_SECONDS := 28.0

var _failures := 0

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	for chapter: Array in Game.chapters:
		await _run_lane(String(chapter[0]), String(chapter[1]))
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _run_lane(id: String, path: String) -> void:
	Save.clear()
	var chapter := (load(path) as PackedScene).instantiate() as Chapter
	chapter.prepare(Chapter.Mode.FINALE)
	add_child(chapter)
	var lane := chapter.get_node(^"ChaseLane") as Node2D
	var walls := lane.get_node(^"Walls") as TileMapLayer
	var entry := lane.get_node(^"Entry") as Node2D
	var exit := lane.get_node(^"Exit") as Node2D
	var start := walls.local_to_map(walls.to_local(entry.global_position))
	var goal := walls.local_to_map(walls.to_local(exit.global_position))
	var route := _path(walls, start, goal)
	_check("%s：赛道能从 Entry 走到 Exit" % id, route.size() > 2, "%d 个路点" % route.size())
	if route.size() <= 2:
		chapter.queue_free()
		return

	var player := PLAYER_SCENE.instantiate() as Player
	player.aim_from_mouse = false
	player.position = entry.position
	lane.add_child(player)
	while player.state != Player.State.ACTIVE:
		await get_tree().physics_frame

	# 路点：每 4 格取一个，再补上终点。
	var points: Array[Vector2] = []
	for i in range(0, route.size(), 4):
		points.append(walls.to_global(walls.map_to_local(route[i])))
	points.append(exit.global_position)
	var took := 0
	var reached := false
	Input.action_press("move_left")
	for i in int(MAX_SECONDS * 60.0):
		await get_tree().physics_frame
		took = i
		if player.state != Player.State.ACTIVE:
			continue
		while points.size() > 1 and (player.global_position.distance_to(points[0]) < 40.0 or points[0].x > player.global_position.x + 12.0):
			points.pop_front()
		var target := points[0]
		var dy := target.y - player.global_position.y
		# 要拐弯就先松方向刹一脚（真人也是这么过的），拐完再加速
		var corner := absf(target.x - player.global_position.x) < 90.0 and absf(dy) > 40.0
		_press(&"move_left", not corner)
		_press(&"move_up", dy < -20.0)
		_press(&"move_down", dy > 20.0)
		if points.size() == 1 and player.global_position.distance_to(points[0]) < 70.0:
			reached = true
			break
	Input.action_release("move_left")
	_press(&"move_up", false)
	_press(&"move_down", false)
	_check("%s：跑到了 Exit" % id, reached, "用了 %.1f 秒，停在 x=%.0f（出口 x=%.0f）" % [took / 60.0, player.global_position.x, exit.global_position.x])
	chapter.queue_free()
	await get_tree().physics_frame

func _press(action: StringName, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)

## 赛道图块上的 BFS：没铺墙的格子都能走。返回格子的路径。
func _path(walls: TileMapLayer, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var solid := {}
	for cell in walls.get_used_cells():
		solid[cell] = true
	# 地图外面的格子没有图块，不限定范围的话寻路会绕出地图。
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
