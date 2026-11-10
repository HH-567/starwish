extends Node
## 困难模式的补给：邮差房里那颗"必留"的小星星。
## 长夜级/永夜级要在（不然摸黑进去救不了邮差），普通模式不占这份便宜；
## 它也不能被"只留敌人附近"那条规则收走。
##   godot --headless --path . --fixed-fps 60 res://tests/test_hard_supply.tscn

const LEVEL := "res://scenes/levels/ch3_crack.tscn"
## 邮差房里那颗补给的位置（第 16 行、第 7 列的格子中心）。
const AT := Vector2(7 * 32 + 16, 16 * 32 + 16)

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())

class Runner extends Node:
	var _failures := 0
	var _chapter: Chapter

	func _ready() -> void:
		Game.debug_no_decay = true
		Save.clear()
		await _load(0)
		_check("普通模式：邮差房里没有这颗补给", _kept() == 0, "%d" % _kept())
		Game.debug_no_decay = false
		await _load(2)
		_check("永夜级：邮差房里有这颗补给", _kept() == 1, "%d" % _kept())
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check("永夜级：它没被「只留敌人附近」收走", _kept() == 1, "%d" % _kept())
		var shard := _shard()
		_check("它就摆在邮差房里（离邮差两个格子）", shard != null and shard.global_position.distance_to(AT) < 1.0, "%s" % [shard.global_position if shard != null else Vector2.ZERO])
		var player := get_tree().get_first_node_in_group(&"player") as Player
		player.light = 10.0
		player.global_position = AT
		var before := player.light
		for i in 6:
			await get_tree().physics_frame
		_check("碰到它：光条回上去了", player.light > before + 1.0, "%.1f -> %.1f" % [before, player.light])
		_close()
		Game.debug_no_decay = true
		Save.clear()
		print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
		get_tree().quit(1 if _failures > 0 else 0)

	func _load(difficulty: int) -> void:
		_close()
		Save.difficulty = difficulty
		_chapter = (load(LEVEL) as PackedScene).instantiate() as Chapter
		_chapter.prepare(Chapter.Mode.NORMAL)
		add_child(_chapter)
		await get_tree().physics_frame

	func _close() -> void:
		if is_instance_valid(_chapter):
			_chapter.free()
		_chapter = null

	func _shard() -> StarShard:
		for node in _chapter.find_children("*", "StarShard", true, false):
			var s := node as StarShard
			if s.hard_only:
				return s
		return null

	func _kept() -> int:
		var n := 0
		for node in _chapter.find_children("*", "StarShard", true, false):
			if (node as StarShard).hard_only:
				n += 1
		return n

	func _check(name: String, ok: bool, detail := "") -> void:
		if not ok:
			_failures += 1
		print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])