extends Node
## 永夜级（困难）多出来的影鬼必须站在空地上，不能卡进墙里（之前会直接摆在墙格里）。
## 只查"多出来的那几只"：关卡里原有的影鬼本来就贴着墙角摆，那是设计。
##   godot --headless --path . --fixed-fps 60 res://tests/test_difficulty_enemies.tscn

const CHAPTERS := ["res://scenes/levels/ch1_vine.tscn", "res://scenes/levels/ch3_crack.tscn"]

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())

class Runner extends Node:
	var _failures := 0
	## 当前打开的那一章（测试自己拿着引用，不靠 SceneTree.current_scene）。
	var _chapter: Chapter

	func _ready() -> void:
		Save.path = "user://test_difficulty_enemies.json"
		Save.clear()
		Game.debug_no_decay = true
		for path: String in CHAPTERS:
			var base := await _open(path, 0)
			var base_at := _positions()
			var hard := await _open(path, 2)
			var name := path.get_file()
			_check("%s 永夜级会多放影鬼（%d -> %d）" % [name, base, hard], hard > base)
			var walls := _chapter.get_node(^"Level/Walls") as TileMapLayer
			var clones := 0
			var bad := 0
			for e in _chapter.find_children("*", "Enemy", true, false):
				var at := (e as Node2D).global_position
				if base_at.has(at):
					continue
				clones += 1
				if not _on_open_ground(walls, at, (e as Enemy).radius):
					bad += 1
			_check("%s 多出来的影鬼都落在空地上" % name, clones > 0 and bad == 0,
				"多出 %d 只，其中 %d 只压墙" % [clones, bad])
			_close()
		Save.difficulty = 0
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_difficulty_enemies.json"))
		print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
		get_tree().quit(1 if _failures > 0 else 0)

	## 按指定难度打开一章，返回影鬼数量（上一章会被关掉）。
	func _open(path: String, difficulty: int) -> int:
		_close()
		Save.difficulty = difficulty
		_chapter = (load(path) as PackedScene).instantiate() as Chapter
		_chapter.prepare(Chapter.Mode.NORMAL)
		add_child(_chapter)
		await get_tree().process_frame
		return _chapter.find_children("*", "Enemy", true, false).size()

	func _positions() -> Array:
		var out := []
		for e in _chapter.find_children("*", "Enemy", true, false):
			out.append((e as Node2D).global_position)
		return out

	func _close() -> void:
		if is_instance_valid(_chapter):
			_chapter.free()
		_chapter = null

	## 影鬼整只（半径 + 余量）都在空地上。
	func _on_open_ground(walls: TileMapLayer, at: Vector2, radius: float) -> bool:
		var used := walls.get_used_rect()
		var local := walls.to_local(at)
		for i in 9:
			var p := local if i == 0 else local + Vector2.from_angle(TAU * float(i - 1) / 8.0) * (radius + 8.0)
			var cell := walls.local_to_map(p)
			if not used.has_point(cell):
				return false
			if walls.get_cell_tile_data(cell) != null:
				return false
		return true

	func _check(name: String, ok: bool, detail := "") -> void:
		if not ok:
			_failures += 1
		print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
