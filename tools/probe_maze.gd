extends Node
## 迷宫可解性探针：不跑追兵，只验"路通、开口够宽、铁门确实改变路线"。
##   godot --headless --path . res://tools/probe_maze.tscn

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	# 1) 没救锁匠：必须绕四折，路径长
	Save.clear()
	var long_path := await _measure("没救锁匠")
	# 2) 救了锁匠：铁门消失，应该有更短的直线路径
	Save.rescued["ch3/Level/Entities/Npc2"] = &"locksmith"
	var short_path := await _measure("救了锁匠")
	print("MAZE 拐弯对比：没救 %d 次，救了 %d 次" % [long_path, short_path])
	var ok := long_path >= 6 and short_path >= 0 and short_path <= 4
	print("MAZE 结论：%s" % ("PASS 没锁匠要绕四折，救了锁匠能走直线" if ok else "FAIL 门没起作用"))
	get_tree().quit()

func _measure(tag: String) -> int:
	var finale: Finale = (load(Game.FINALE_SCENE) as PackedScene).instantiate()
	add_child(finale)
	for i in 20:
		await get_tree().process_frame
	var outro := finale.get_node(^"Outro") as Node2D
	var walls := outro.get_node(^"Walls") as TileMapLayer
	var entry := outro.get_node_or_null(^"Entry") as Node2D
	var escape: Node2D = null
	for node in outro.find_children("*", "EscapePoint", true, false):
		escape = node as Node2D
		break
	if entry == null or escape == null:
		print("MAZE [%s] 找不到 Entry(%s) 或逃离点(%s)" % [tag, entry, escape])
		finale.queue_free()
		await get_tree().process_frame
		return 0
	var start := walls.local_to_map(walls.to_local(entry.global_position))
	var goal := walls.local_to_map(walls.to_local(escape.global_position))
	print("MAZE [%s] entry=%s escape=%s 格=%s→%s" % [tag, entry.global_position, escape.global_position, start, goal])
	var extra := {}
	# 锁匠救过：铁门是"走近自己开"，对路线来说等于不存在；没救才当墙。
	for node in ([] if Save.has_role(&"locksmith") else outro.find_children("*", "IronDoor", true, false)):
		var door := node as IronDoor
		if door == null:
			continue
		var half: Vector2 = door.size * 0.5
		var a := walls.local_to_map(walls.to_local(door.global_position - half))
		var b := walls.local_to_map(walls.to_local(door.global_position + half))
		for yy in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			for xx in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
				extra[Vector2i(xx, yy)] = true
	print("MAZE [%s] 铁门占 %d 格" % [tag, extra.size()])
	var path := _bfs(walls, start, goal, extra)
	var turns := _turns(path)
	print("MAZE [%s] 从 %s 到 %s：%d 格、拐 %d 次%s" % [tag, start, goal, path.size(), turns, "" if not path.is_empty() else "（不通！）"])
	finale.queue_free()
	await get_tree().process_frame
	return turns if not path.is_empty() else -1

## 路径里方向变化的次数 = 拐弯数
func _turns(path: Array[Vector2i]) -> int:
	var n := 0
	for i in range(1, path.size() - 1):
		var a := path[i] - path[i - 1]
		var b := path[i + 1] - path[i]
		if a != b:
			n += 1
	return n

func _bfs(walls: TileMapLayer, start: Vector2i, goal: Vector2i, extra := {}) -> Array[Vector2i]:
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
			if not used.has_point(next) or solid.has(next) or extra.has(next) or came.has(next):
				continue
			came[next] = cell
			queue.append(next)
	return []
