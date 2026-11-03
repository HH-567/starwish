extends Node
## 序章（ch0）通关测试：撞墙的代价、小星星回亮度、救守夜人、检查点、出口，
## 以及终章模式下这一段赛道的入口、出口、守夜人帮助点都接得上。
##   godot --headless --path . --fixed-fps 60 res://tests/test_ch0.tscn

const LEVEL := "res://scenes/levels/ch0_fall.tscn"

var _failures := 0
var _player: Player
var _events: Array[StringName] = []
var _hints: Array[String] = []

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Save.clear()
	Game.npc_rescued.connect(func(_id: String) -> void: _events.append(&"rescued"))
	Game.checkpoint_reached.connect(func(_id: String) -> void: _events.append(&"checkpoint"))
	Game.chapter_cleared.connect(func(_c: StringName) -> void: _events.append(&"cleared"))
	Game.hint_shown.connect(func(text: String) -> void: _hints.append(text))
	add_child((load(LEVEL) as PackedScene).instantiate())
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_player.aim_from_mouse = false
	_check("从 PlayerStart 出生", _player.global_position.distance_to(_cell(Vector2i(3, 20))) < 1.0, "%s" % _player.global_position)
	var finished: Variant = await _walk()
	_check("全部步骤都跑完了", finished == true)
	await _lane()
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])

func _walk() -> bool:
	while _player.state != Player.State.ACTIVE:
		await get_tree().physics_frame

	# 出生房的东墙离出生点 4 格：按住右冲过去正好是阶段 2，撞墙扣 s2_damage。
	var before := _player.light
	var reached := 0
	Input.action_press("move_right")
	for i in 120:
		await get_tree().physics_frame
		reached = maxi(reached, _player.stage)
		if _player.light < before:
			break
	Input.action_release("move_right")
	_check("出生房：按住右撞上东墙时是阶段 2", reached == 2, "最高阶段 %d" % reached)
	_check("阶段 2 撞墙扣掉 s2_damage", is_equal_approx(_player.light, before - Game.tuning.s2_damage), "%.0f → %.0f" % [before, _player.light])
	_check("撞完还活着", _player.state == Player.State.ACTIVE)
	_check("跑向墙的路上浮出撞墙的提示", _hints.has(Hints.TEXT[&"bump"]), "%s" % [_hints])

	# 竖井里的小星星：碰到回 shard_amount。
	var low := _player.light
	_put(Vector2i(4, 15))
	Input.action_press("move_up")
	await _frames(30)
	Input.action_release("move_up")
	_check("竖井：捡到小星星回亮度", _player.light > low, "%.0f → %.0f" % [low, _player.light])
	_check("竖井：浮出小星星的提示", _hints.has(Hints.TEXT[&"shard"]))

	# 守夜人：散射照 2 秒。
	_put(Vector2i(36, 9))
	await _frames(140)
	_check("照亮守夜人", _saved(&"watchman"))
	_check("走到守夜人跟前：浮出救人的提示", _hints.has(Hints.TEXT[&"save"]))
	_check("救到人：亮度上限 +light_per_rescue 并回满", is_equal_approx(_player.light, _player.light_max) and is_equal_approx(_player.light_max, Game.tuning.light_base + Game.tuning.light_per_rescue), "%.0f / %.0f" % [_player.light, _player.light_max])

	# 检查点：走进去就记下。
	_put(Vector2i(31, 9))
	await _frames(10)
	_check("走到检查点：存档记下它", Save.checkpoint == "ch0/Level/Entities/Checkpoint", Save.checkpoint)

	# 出口。
	_put(Vector2i(41, 9))
	_player.velocity = Vector2(300, 0)
	await _frames(30)
	_check("进入出口：发 chapter_cleared", _events.has(&"cleared"))
	return true

## 终章模式：这一章的回程赛道能接上，守夜人的帮助点认得出关卡区里的那个人。
func _lane() -> void:
	var chapter := (load(LEVEL) as PackedScene).instantiate() as Chapter
	var npc := _find_npc(chapter)
	var lane := chapter.get_node(^"ChaseLane") as Node2D
	var entry := lane.get_node_or_null(^"Entry") as Node2D
	var exit := lane.get_node_or_null(^"Exit") as Node2D
	_check("赛道有 Entry 和 Exit", entry != null and exit != null)
	if entry != null and exit != null:
		_check("Entry 在最右、Exit 在最左、同高", entry.position.x > exit.position.x and is_equal_approx(entry.position.y, exit.position.y), "%s → %s" % [entry.position, exit.position])
	var helps := lane.find_children("*", "HelpPoint", true, false)
	_check("赛道里只有守夜人一个帮助点", helps.size() == 1 and helps[0].role == "watchman", "%d 个" % helps.size())
	if helps.size() == 1 and npc != null:
		var help := helps[0] as HelpPoint
		help.resolve()
		_check("帮助点指向关卡区里的守夜人", help.npc_id == Save.id_of(npc), "%s" % help.npc_id)
		var lamps := help.find_children("*", "Lamp", true, false)
		_check("帮助点下面挂着路灯", lamps.size() > 0, "%d 盏" % lamps.size())
	chapter.prepare(Chapter.Mode.FINALE)
	_check("终章模式：只剩回程赛道", chapter.get_node_or_null(^"Level") == null and chapter.get_node_or_null(^"ChaseLane") != null)
	chapter.free()

func _find_npc(chapter: Chapter) -> Npc:
	for node in chapter.find_children("*", "Npc", true, false):
		return node as Npc
	return null

func _cell(c: Vector2i) -> Vector2:
	return Vector2(c * 32) + Vector2(16, 16)

func _put(c: Vector2i) -> void:
	_player.global_position = _cell(c)
	_player.velocity = Vector2.ZERO
	_player.light_mode = Player.LightMode.SCATTER
	_player.aim = Vector2.RIGHT

func _saved(role: StringName) -> bool:
	return Save.has_role(role)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
