extends Node
## 第二章（ch1）通关测试：影藤挡路要聚光烧、园丁封在影藤后面、玻璃房里的医生照不到（进等邮差的名单）、
## 检查点、出口，以及终章模式下这一段赛道的两个帮助点（园丁的花、医生）。
##   godot --headless --path . --fixed-fps 60 res://tests/test_ch1.tscn

const LEVEL := "res://scenes/levels/ch1_vine.tscn"

var _failures := 0
var _player: Player
var _burnt := 0
var _cleared := 0

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Save.clear()
	Game.vine_burnt.connect(func(_id: String) -> void: _burnt += 1)
	Game.chapter_cleared.connect(func(_c: StringName) -> void: _cleared += 1)
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

	# 影藤门：散射照不穿，聚光才烧得断。
	_put(Vector2i(15, 21), Player.LightMode.SCATTER)
	await _frames(60)
	_check("散射照影藤门：烧不断", _burnt == 0, "%d" % _burnt)
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	_check("影藤门挡住去路", _player.global_position.x < 18.0 * 32.0, "x=%.0f" % _player.global_position.x)

	_put(Vector2i(16, 21), Player.LightMode.FOCUS, Vector2.RIGHT)
	await _frames(120)
	_check("聚光烧断影藤门", _burnt == 1, "%d" % _burnt)
	_check("烧掉的影藤写进存档", Save.burnt.size() == 1)

	# 园丁封在影藤后面：先烧开，再照亮。
	_put(Vector2i(33, 19), Player.LightMode.SCATTER)
	await _frames(60)
	_check("园丁被影藤挡着，照不到", not _saved(&"gardener"))
	_put(Vector2i(33, 19), Player.LightMode.FOCUS, Vector2.UP)
	await _frames(130)
	_check("聚光烧开壁龛的影藤", _burnt == 2, "%d" % _burnt)
	await _frames(140)
	_check("照亮园丁", _saved(&"gardener"))

	# 玻璃房：进不去，但能从下方通风口把医生照到（医生是可以照亮的版本）。
	_put(Vector2i(50, 21), Player.LightMode.SCATTER)
	await _frames(6)
	_put(Vector2i(54, 21), Player.LightMode.SCATTER)
	await _frames(200)
	_check("隔着通风口照亮医生", _saved(&"doctor"), "%s" % [Save.rescued])
	_put(Vector2i(53, 21), Player.LightMode.SCATTER)
	Input.action_press("move_up")
	await _frames(60)
	Input.action_release("move_up")
	_check("玻璃挡住小星，进不去", _player.global_position.y > 19.0 * 32.0, "y=%.0f" % _player.global_position.y)

	# 检查点、出口。
	_put(Vector2i(44, 20), Player.LightMode.SCATTER)
	await _frames(10)
	_check("走到检查点：存档记下它", Save.checkpoint == "ch1/Level/Entities/Checkpoint", Save.checkpoint)
	_player.global_position = _exit_pos()
	await _frames(10)
	_check("进入出口：发 chapter_cleared", _cleared == 1)
	return true

## 终章模式：赛道上有园丁和医生两个帮助点，园丁的花挂在他下面。
func _lane() -> void:
	var chapter := (load(LEVEL) as PackedScene).instantiate() as Chapter
	var lane := chapter.get_node(^"ChaseLane") as Node2D
	_check("赛道有 Entry 和 Exit", lane.get_node_or_null(^"Entry") != null and lane.get_node_or_null(^"Exit") != null)
	var helps := lane.find_children("*", "HelpPoint", true, false)
	var roles: Array[String] = []
	for help: HelpPoint in helps:
		roles.append(help.role)
	roles.sort()
	_check("赛道里有园丁和医生两个帮助点", roles == ["doctor", "gardener"], "%s" % [roles])
	for help: HelpPoint in helps:
		if help.role == "gardener":
			var flowers := help.find_children("*", "AccelStrip", true, false)
			_check("园丁下面挂着他的花", flowers.size() == 1 and flowers[0].flowers, "%d" % flowers.size())
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

## 出口在哪由场景说了算（关卡会加长、出口会挪），测试别写死格子。
func _exit_pos() -> Vector2:
	for node in get_tree().current_scene.find_children("*", "Exit", true, false):
		return (node as Node2D).global_position
	return Vector2.ZERO
