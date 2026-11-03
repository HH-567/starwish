extends Node
## 真实终章的追逐探针：不救任何人，让自动驾驶从开头一路往逃离点跑，
## 报告"死了几次""噬光者贴到多近"。路点从赛道图块里 BFS 算，赛道怎么改都能跑。
## 注意：这条**不是及格线**。自动驾驶只会"松方向刹一脚、再拐"，比真人差一截，
## 它跑不完不代表人跑不完；它的用处是给平衡调参一个固定的测量口径。
##   godot --headless --path . --fixed-fps 60 res://tests/test_chase.tscn
## 会换场景，所以逻辑挂在 root 下的 Runner 上，不然换场景时自己先被删了。

const MAX_SECONDS := 120.0

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())

class Runner extends Node:
	var _failures := 0
	var _deaths := 0
	var _min_gap := 99999.0

	func _ready() -> void:
		Game.player_died.connect(func(c: int) -> void:
			_deaths += 1
			print("DEATH cause=", ["熄灭", "碎裂", "吸干"][c]))
		Save.clear()
		Game.debug_no_decay = false
		var finished: Variant = await _run()
		_check("探针跑完了一轮", finished is bool)
		print("CHASE_DEATHS %d" % _deaths)
		print("CHASE_MIN_GAP %.0f" % _min_gap)
		print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
		get_tree().quit(1 if _failures > 0 else 0)

	func _run() -> bool:
		Game.flow = Game.Flow.PLAYING
		Save.checkpoint = ""
		get_tree().change_scene_to_file(Game.FINALE_SCENE)
		await get_tree().process_frame
		for i in 900:
			await get_tree().physics_frame
			var f := _finale()
			if f != null and f.player != null and f.player.state == Player.State.ACTIVE:
				break
		var finale := _finale()
		if finale == null or finale.player == null:
			return false
		var points := _waypoints(finale)
		_check("从赛道算出了路点", points.size() > 20, "%d 个" % points.size())
		var player := finale.player
		var total := points.size()
		var progress := 0
		Input.action_press("move_left")
		var reached := false
		for i in int(MAX_SECONDS * 60.0):
			await get_tree().physics_frame
			if Game.flow == Game.Flow.ENDING:
				reached = true
				break
			if not is_instance_valid(player) or _finale() != finale:
				# 死了会重新加载终章：重新算路点接着跑。
				finale = _finale()
				if finale == null or finale.player == null:
					continue
				player = finale.player
				points = _waypoints(finale)
				continue
			if player.state != Player.State.ACTIVE:
				_steer(Vector2.ZERO)
				continue
			var boss := finale.boss
			if boss != null and boss.state == Boss.State.CHASE:
				_min_gap = minf(_min_gap, boss.gap())
			while points.size() > 1 and (player.global_position.distance_to(points[0]) < 48.0 or points[0].x > player.global_position.x + 16.0):
				points.pop_front()
			progress = maxi(progress, total - points.size())
			var target := points[0]
			var dy := target.y - player.global_position.y
			var corner := absf(target.x - player.global_position.x) < 90.0 and absf(dy) > 40.0
			_steer(Vector2(0.0 if corner else -1.0, signf(dy) if absf(dy) > 20.0 else 0.0))
		Input.action_release("move_left")
		_steer(Vector2.ZERO)
		# 只报告数据，不判及格：自动驾驶的水平比真人差，见文件头的说明。
		print("CHASE_PROGRESS %d/%d" % [progress, total])
		return reached

	func _steer(v: Vector2) -> void:
		_press(&"move_left", v.x < 0.0)
		_press(&"move_right", v.x > 0.0)
		_press(&"move_up", v.y < 0.0)
		_press(&"move_down", v.y > 0.0)

	func _press(action: StringName, on: bool) -> void:
		if on:
			Input.action_press(action)
		else:
			Input.action_release(action)

	func _finale() -> Finale:
		return get_tree().current_scene as Finale

	## 每段赛道各算一条路，接起来；最后指向逃离点。
	func _waypoints(finale: Finale) -> Array[Vector2]:
		var out: Array[Vector2] = []
		for child in finale.get_children():
			if not child is Chapter:
				continue
			var lane := child.get_node_or_null(^"ChaseLane") as Node2D
			if lane == null:
				continue
			var walls := lane.get_node(^"Walls") as TileMapLayer
			var entry := lane.get_node(^"Entry") as Node2D
			var exit := lane.get_node(^"Exit") as Node2D
			var route := _path(walls, walls.local_to_map(walls.to_local(entry.global_position)), walls.local_to_map(walls.to_local(exit.global_position)))
			for i in range(0, route.size(), 4):
				out.append(walls.to_global(walls.map_to_local(route[i])))
			out.append(exit.global_position)
		for node in finale.find_children("*", "EscapePoint", true, false):
			out.append((node as Node2D).global_position)
		return out

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
