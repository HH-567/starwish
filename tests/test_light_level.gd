extends Node
## 光照测试关通关测试：按顺序把小星摆到每个人前面，确认这张图能把 12 个人都救出来。
##   godot --headless --path . --fixed-fps 60 res://tests/test_light_level.tscn
## 守夜人 → 烧影藤救园丁 → 医生照不到 → 烧影藤门 → 钟表匠、向导 → 潜望镜救画家（小星过不去拐角）
## → 乐手和听众 → 长跑道 4 档撞碎裂纹墙 → 矿工 → 隔着栅栏救锁匠，铁门打开 → 科学家
## → 虫洞回出生大厅 → 铁门后的邮差 → 医生收到信 → 进出口。

const LEVEL := "res://scenes/levels/test_light.tscn"

var _failures := 0
var _player: Player
var _events: Array[StringName] = []
var _arrived_at := Vector2.ZERO

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Save.clear()
	Game.npc_rescued.connect(func(_id: String) -> void: _events.append(&"rescued"))
	Game.vine_burnt.connect(func(_id: String) -> void: _events.append(&"burnt"))
	Game.wall_broken.connect(func(_id: String) -> void: _events.append(&"broken"))
	Game.chapter_cleared.connect(func(_c: StringName) -> void: _events.append(&"cleared"))
	Game.warped.connect(func() -> void:
		_events.append(&"warped")
		_arrived_at = _player.global_position)
	# 存档里的检查点在这一关：从检查点出生。
	Save.checkpoint = "test_light/Level/Entities/Checkpoint"
	add_child((load(LEVEL) as PackedScene).instantiate())
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_player.aim_from_mouse = false
	_check("从存档里的检查点出生", _player.global_position == _cell(Vector2i(4, 23)), "%s" % _player.global_position)
	var finished: Variant = await _walk()
	_check("全部步骤都跑完了", finished == true)
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])

func _walk() -> bool:
	while _player.state != Player.State.ACTIVE:
		await get_tree().physics_frame
	_check("开局有两扇铁门", _doors() == 2, "%d" % _doors())

	_put(Vector2i(15, 5), Player.LightMode.SCATTER)
	await _frames(130)
	_check("出生大厅：散射救出守夜人", _saved(&"watchman"))

	_put(Vector2i(33, 7), Player.LightMode.FOCUS, Vector2.UP)
	await _frames(100)
	_check("影藤大厅：聚光烧断坑口的影藤", _count(&"burnt") == 1)
	await _frames(130)
	_check("影藤大厅：救出坑里的园丁", _saved(&"gardener"))

	_put(Vector2i(38, 11), Player.LightMode.SCATTER)
	await _frames(130)
	_check("玻璃窗后的医生照不到，记进等邮差的名单", not _saved(&"doctor") and Save.mail.values().has(&"doctor"))

	_put(Vector2i(39, 7), Player.LightMode.FOCUS, Vector2.RIGHT)
	await _frames(100)
	_check("影藤门：聚光烧断", _count(&"burnt") == 2)

	_put(Vector2i(53, 8), Player.LightMode.SCATTER)
	await _frames(130)
	_check("玻璃房：救出钟表匠", _saved(&"clockmaker"))
	_put(Vector2i(58, 4), Player.LightMode.SCATTER)
	await _frames(130)
	_check("玻璃房角落：救出向导", _saved(&"guide"))

	_put(Vector2i(50, 12), Player.LightMode.SCATTER)
	Input.action_press("move_left")
	Input.action_press("move_down")
	await _frames(90)
	Input.action_release("move_left")
	Input.action_release("move_down")
	_check("潜望镜：拐角的玻璃挡住小星", _player.global_position.y < 420.0, "%s" % _player.global_position)
	_put(Vector2i(52, 12), Player.LightMode.FOCUS, Vector2.LEFT)
	_player.light = 40.0
	await _frames(130)
	_check("潜望镜：亮度 40 时聚光经玻璃照到画家", _saved(&"painter"))

	_put(Vector2i(26, 16), Player.LightMode.SCATTER)
	await _frames(100)
	_check("结伴房：乐手和听众一起得救", _saved(&"musician") and _saved(&"listener"))

	_put(Vector2i(4, 27), Player.LightMode.SCATTER)
	Input.action_press("move_right")
	var reached := 0
	for i in 360:
		await get_tree().physics_frame
		reached = maxi(reached, _player.stage)
		if _count(&"broken") > 0:
			break
	Input.action_release("move_right")
	_check("长跑道：没有加速带，按住右冲到 4 档撞碎裂纹墙", _count(&"broken") == 1 and reached == 4, "最高阶段 %d" % reached)

	await _frames(30)
	_put(Vector2i(58, 29), Player.LightMode.SCATTER)
	await _frames(130)
	_check("裂纹墙后：救出矿工，隔着栅栏的锁匠这里照不到", _saved(&"miner") and not _saved(&"locksmith"))

	_put(Vector2i(55, 26), Player.LightMode.SCATTER)
	await _frames(130)
	_check("隔着栅栏救出锁匠", _saved(&"locksmith"))
	await _frames(2)
	_check("锁匠被救：本关的铁门都打开了", _doors() == 0, "%d" % _doors())

	_put(Vector2i(59, 26), Player.LightMode.SCATTER)
	await _frames(130)
	_check("铁门后：救出科学家（向导已救，听得见）", _saved(&"scientist"))

	_put(Vector2i(57, 29), Player.LightMode.SCATTER)
	_player.velocity = Vector2(300, 0)
	await _frames(40)
	_check("虫洞：回到出生大厅", _count(&"warped") == 1 and _arrived_at.distance_to(_cell(Vector2i(9, 10))) < 40.0, "%s" % _arrived_at)

	_put(Vector2i(6, 12), Player.LightMode.SCATTER)
	await _frames(130)
	_check("回头：出生大厅铁门后救出邮差", _saved(&"postman"))
	_check("邮差被救：医生收到信也得救", _saved(&"doctor"))
	_check("12 个人全部救出，上限仍是 60", Save.rescued.size() == 12 and _player.light_max == 60.0, "%d 人，上限 %.0f" % [Save.rescued.size(), _player.light_max])

	_put(Vector2i(5, 3), Player.LightMode.SCATTER)
	_player.velocity = Vector2(-300, 0)
	await _frames(40)
	_check("进入出口：发 chapter_cleared", _count(&"cleared") == 1)
	return true

func _cell(c: Vector2i) -> Vector2:
	return Vector2(c * 32) + Vector2(16, 16)

func _put(c: Vector2i, mode: Player.LightMode, aim := Vector2.RIGHT) -> void:
	_player.global_position = _cell(c)
	_player.velocity = Vector2.ZERO
	_player.light_mode = mode
	_player.aim = aim

func _saved(role: StringName) -> bool:
	return Save.has_role(role)

## 关里还剩几扇铁门。
func _doors() -> int:
	return get_tree().current_scene.find_children("*", "IronDoor", true, false).size()

func _count(kind: StringName) -> int:
	return _events.count(kind)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
