extends Node
## 第五章（ch4）通关测试：乐手和听众要同时被照到、钟表匠、铁门后的笼子里的科学家（隔着栅栏照）、出口，
## 以及终章模式下乐手/听众/钟表匠三个帮助点。
##   godot --headless --path . --fixed-fps 60 res://tests/test_ch4.tscn
## 前半段用"没救锁匠"的存档：铁门关着，科学家进不去；后半段把锁匠记成已救、重新加载这一章，
## 铁门不再出现，才救得到科学家。

const LEVEL := "res://scenes/levels/ch4_pair.tscn"

var _failures := 0
var _player: Player
var _chapter: Chapter
var _cleared := 0

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Save.clear()
	Game.chapter_cleared.connect(func(_c: StringName) -> void: _cleared += 1)
	await _load()
	_check("从 PlayerStart 出生", _player.global_position.distance_to(_cell(Vector2i(3, 22))) < 1.0, "%s" % _player.global_position)
	var finished: Variant = await _walk()
	_check("全部步骤都跑完了", finished == true)
	var second: Variant = await _after_locksmith()
	_check("重新加载后也跑完了", second == true)
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

	# 结伴：只照到一个不算数，两个同时照到才一起得救。
	_put(Vector2i(24, 19), Player.LightMode.SCATTER)
	await _frames(6)
	_put(Vector2i(26, 21), Player.LightMode.FOCUS, Vector2.UP)
	await _frames(150)
	_check("只照到乐手一个人：不得救", not _saved(&"musician") and not _saved(&"listener"))
	_put(Vector2i(27, 20), Player.LightMode.SCATTER)
	await _frames(120)
	_check("两个人同时被照到：一起得救", _saved(&"musician") and _saved(&"listener"))

	# 钟表匠。
	_put(Vector2i(50, 18), Player.LightMode.SCATTER)
	await _frames(140)
	_check("照亮钟表匠", _saved(&"clockmaker"))

	# 铁门关着：科学家那间进不去。
	_check("没救锁匠：铁门还在", _doors() == 1, "%d" % _doors())
	_put(Vector2i(56, 18), Player.LightMode.SCATTER)
	Input.action_press("move_right")
	await _frames(60)
	Input.action_release("move_right")
	_check("铁门挡住小星", _player.global_position.x < 57.0 * 32.0, "x=%.0f" % _player.global_position.x)
	_check("铁门后的科学家还照不到", not _saved(&"scientist"))
	return true

## 假装 ch3 已经救了锁匠：重新加载这一章，铁门不出现，救笼子里的科学家。
func _after_locksmith() -> bool:
	Save.rescued["ch3/Level/Entities/Npc2"] = &"locksmith"
	await _load()
	# 锁匠救过：门还在，但小星走近会自己打开（有 0.3 秒收门动画）
	_check("锁匠已救：门还在", _doors() == 1, "%d" % _doors())
	_put(Vector2i(60, 20), Player.LightMode.SCATTER)
	await _frames(40)
	_check("走近之后门打开", _doors() == 0, "%d" % _doors())
	_put(Vector2i(63, 20), Player.LightMode.SCATTER, Vector2.UP)
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	_check("栅栏挡住小星，进不去笼子", _player.global_position.y > 18.0 * 32.0, "y=%.0f" % _player.global_position.y)
	await _frames(140)
	_check("隔着栅栏照亮科学家", _saved(&"scientist"))
	_player.global_position = _exit_pos()
	await _frames(10)
	_check("进入出口：发 chapter_cleared", _cleared == 1)
	return true

func _load() -> void:
	if _chapter != null:
		_chapter.queue_free()
		await get_tree().physics_frame
		await get_tree().physics_frame
	_chapter = (load(LEVEL) as PackedScene).instantiate() as Chapter
	add_child(_chapter)
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_player.aim_from_mouse = false
	while _player.state != Player.State.ACTIVE:
		await get_tree().physics_frame

## 终章模式：赛道上乐手、听众、钟表匠三个帮助点。
func _lane() -> void:
	var chapter := (load(LEVEL) as PackedScene).instantiate() as Chapter
	var lane := chapter.get_node(^"ChaseLane") as Node2D
	var helps := lane.find_children("*", "HelpPoint", true, false)
	var roles: Array[String] = []
	for help: HelpPoint in helps:
		roles.append(help.role)
	roles.sort()
	_check("赛道里有乐手、听众、钟表匠", roles == ["clockmaker", "listener", "musician"], "%s" % [roles])
	chapter.free()

func _doors() -> int:
	return _chapter.find_children("*", "IronDoor", true, false).size()

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
