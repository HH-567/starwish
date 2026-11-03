extends Node
## 第四章（ch3）通关测试：铁门挡着邮差、加速带推到阶段 4 撞碎裂纹墙、矿工、
## 隔着栅栏救锁匠（进不去）→ 铁门开 → 回头救邮差 → 邮差把 ch1 玻璃房里的医生一起点亮、检查点、出口，
## 以及终章模式下矿工的隧道。
##   godot --headless --path . --fixed-fps 60 res://tests/test_ch3.tscn

const LEVEL := "res://scenes/levels/ch3_crack.tscn"
## 假装 ch1 已经加载过：医生登记在等邮差的名单里。
const DOCTOR_ID := "ch1/Level/Entities/Npc2"

var _failures := 0
var _player: Player
var _broken := 0
var _cleared := 0
var _postman: Npc

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Save.clear()
	Save.mail[DOCTOR_ID] = &"doctor"
	Game.wall_broken.connect(func(_id: String) -> void: _broken += 1)
	Game.chapter_cleared.connect(func(_c: StringName) -> void: _cleared += 1)
	add_child((load(LEVEL) as PackedScene).instantiate())
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_player.aim_from_mouse = false
	for npc: Npc in get_tree().get_nodes_in_group(&"npc"):
		if npc.role == "postman":
			_postman = npc
	_check("从 PlayerStart 出生", _player.global_position.distance_to(_cell(Vector2i(3, 24))) < 1.0, "%s" % _player.global_position)
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

	# 铁门：挡路，邮差藏在后面（向导没救，他不出声）。
	_check("开局有铁门", _doors() == 1, "%d" % _doors())
	_check("邮差藏着：向导没救之前不出声", _postman != null and not _postman.is_heard())
	_put(Vector2i(5, 21))
	Input.action_press("move_up")
	await _frames(60)
	Input.action_release("move_up")
	_check("铁门挡住去路", _player.global_position.y > 19.0 * 32.0, "y=%.0f" % _player.global_position.y)

	# 长直道：按住右跑到阶段 4，撞碎裂纹墙（关卡区没有加速带，WASD 自己能到阶段 4）。
	_put(Vector2i(26, 20))
	Input.action_press("move_right")
	var reached := 0
	for i in 300:
		await get_tree().physics_frame
		reached = maxi(reached, _player.stage)
		if _broken > 0:
			break
	Input.action_release("move_right")
	_check("长直道把速度推到阶段 4", reached >= 4, "最高阶段 %d" % reached)
	_check("阶段 4 撞碎裂纹墙", _broken == 1, "%d" % _broken)
	_check("撞碎的墙写进存档", Save.broken.size() == 1)

	# 矿工在墙后面。
	_put(Vector2i(47, 22))
	await _frames(140)
	_check("照亮裂纹墙后的矿工", _saved(&"miner"))

	# 锁匠：栅栏挡人，不挡光。
	_put(Vector2i(51, 19))
	Input.action_press("move_right")
	await _frames(50)
	Input.action_release("move_right")
	_check("栅栏挡住小星，进不去笼子", _player.global_position.x < 53.0 * 32.0, "x=%.0f" % _player.global_position.x)
	await _frames(140)
	_check("隔着栅栏照亮锁匠", _saved(&"locksmith"))
	await _frames(4)
	_check("锁匠被救：铁门打开", _doors() == 0, "%d" % _doors())

	# 回头：邮差，以及他远程点亮 ch1 的医生。
	_put(Vector2i(5, 20))
	await _frames(140)
	_check("回头救出铁门后的邮差", _saved(&"postman"))
	_check("邮差被救：等邮差的医生一起得救", _saved(&"doctor") and Save.rescued.has(DOCTOR_ID), "%s" % [Save.rescued])

	# 检查点、出口。
	_put(Vector2i(45, 21))
	await _frames(10)
	_check("走到检查点：存档记下它", Save.checkpoint == "ch3/Level/Entities/Checkpoint", Save.checkpoint)
	_player.global_position = _exit_pos()
	await _frames(10)
	_check("进入出口：发 chapter_cleared", _cleared == 1)
	return true

## 终章模式：赛道上有矿工的帮助点，隧道挂在他下面。
func _lane() -> void:
	var chapter := (load(LEVEL) as PackedScene).instantiate() as Chapter
	var lane := chapter.get_node(^"ChaseLane") as Node2D
	var helps := lane.find_children("*", "HelpPoint", true, false)
	_check("赛道里只有矿工一个帮助点", helps.size() == 1 and helps[0].role == "miner", "%d" % helps.size())
	if helps.size() == 1:
		var tunnels := helps[0].find_children("*", "Tunnel", true, false)
		_check("矿工下面挂着隧道", tunnels.size() == 1, "%d" % tunnels.size())
	chapter.free()

func _doors() -> int:
	return get_tree().current_scene.find_children("*", "IronDoor", true, false).size()

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

## 出口在哪由场景说了算（关卡会加长、出口会挪），测试别写死格子。
func _exit_pos() -> Vector2:
	for node in get_tree().current_scene.find_children("*", "Exit", true, false):
		return (node as Node2D).global_position
	return Vector2.ZERO
