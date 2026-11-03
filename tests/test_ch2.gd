extends Node
## 第三章（ch2）通关测试：虫洞是过墙的唯一通路、向导藏在凹角、画家只有反射光照得到、检查点、出口，
## 以及终章模式下这一段赛道的两个帮助点（画家的光门、向导）。
##   godot --headless --path . --fixed-fps 60 res://tests/test_ch2.tscn

const LEVEL := "res://scenes/levels/ch2_mirror.tscn"

var _failures := 0
var _player: Player
var _hints: Array[String] = []
var _warps := 0
var _arrived := Vector2.ZERO
var _cleared := 0

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Save.clear()
	Game.warped.connect(func() -> void:
		_warps += 1
		_arrived = _player.global_position)
	Game.chapter_cleared.connect(func(_c: StringName) -> void: _cleared += 1)
	Game.hint_shown.connect(func(text: String) -> void: _hints.append(text))
	add_child((load(LEVEL) as PackedScene).instantiate())
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_player.aim_from_mouse = false
	_check("从 PlayerStart 出生", _player.global_position.distance_to(_cell(Vector2i(3, 22))) < 1.0, "%s" % _player.global_position)
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

	# 向导窝在凹角里。
	_put(Vector2i(24, 20), Player.LightMode.SCATTER)
	_check("凹角里的向导一开始照不到", not _saved(&"guide"))
	_put(Vector2i(22, 18), Player.LightMode.SCATTER)
	await _frames(140)
	_check("走进凹角才照得到向导", _saved(&"guide"))

	# 虫洞：西房和东房之间隔着一道墙，只能靠虫洞过去。
	_put(Vector2i(29, 20), Player.LightMode.SCATTER)
	_player.velocity = Vector2(300, 0)
	await _frames(40)
	_check("进虫洞 A：从 B 出来", _warps == 1 and _arrived.distance_to(_cell(Vector2i(38, 20)) + Vector2(34, 0)) < 48.0, "%s" % _arrived)

	# 画家：竖井进不去，直接照也照不到，只有对着斜玻璃的反射光能照到。
	_put(Vector2i(36, 17), Player.LightMode.FOCUS, Vector2.UP)
	await _frames(120)
	_check("竖井外面的直接光（朝上）照不到画家", not _saved(&"painter"))
	_put(Vector2i(40, 16), Player.LightMode.SCATTER)
	await _frames(60)
	_check("竖井口光直着往下也照不到", not _saved(&"painter"))
	_put(Vector2i(36, 17), Player.LightMode.FOCUS, Vector2.RIGHT)
	await _frames(150)
	_check("对着斜玻璃照：反射光照到画家", _saved(&"painter"))
	_check("走到斜玻璃前：浮出反射的提示", _hints.has(Hints.TEXT[&"mirror"]), "%s" % [_hints])

	# 检查点、出口。
	_put(Vector2i(44, 21), Player.LightMode.SCATTER)
	await _frames(10)
	_check("走到检查点：存档记下它", Save.checkpoint == "ch2/Level/Entities/Checkpoint", Save.checkpoint)
	_put(Vector2i(53, 20), Player.LightMode.SCATTER)
	_player.velocity = Vector2(300, 0)
	await _frames(40)
	_check("进入出口：发 chapter_cleared", _cleared == 1)
	return true

## 终章模式：赛道上画家和向导两个帮助点，画家的光门挂在他下面。
func _lane() -> void:
	var chapter := (load(LEVEL) as PackedScene).instantiate() as Chapter
	var lane := chapter.get_node(^"ChaseLane") as Node2D
	var helps := lane.find_children("*", "HelpPoint", true, false)
	var roles: Array[String] = []
	for help: HelpPoint in helps:
		roles.append(help.role)
	roles.sort()
	_check("赛道里有画家和向导两个帮助点", roles == ["guide", "painter"], "%s" % [roles])
	for help: HelpPoint in helps:
		if help.role == "painter":
			var doors := help.find_children("*", "Wormhole", true, false)
			_check("画家下面挂着一扇单向光门", doors.size() == 1 and not doors[0].two_way, "%d" % doors.size())
	chapter.free()

func _cell(c: Vector2i) -> Vector2:
	return Vector2(c * 32) + Vector2(16, 16)

func _put(c: Vector2i, mode: Player.LightMode, aim := Vector2.RIGHT) -> void:
	_player.global_position = _cell(c)
	_player.velocity = Vector2.ZERO
	_player.light_mode = mode
	_player.aim = aim

func _saved(role: StringName) -> bool:
	return Save.has_role(role)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
