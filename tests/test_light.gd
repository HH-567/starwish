extends Node2D
## 光和新实体的无头测试。在工程目录运行：
##   godot --headless --path . --fixed-fps 60 res://tests/test_light.tscn
## 每个用例摆好小星和实体，跑若干物理帧，检查结果。全部通过时退出码为 0。

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const NPC_SCENE := preload("res://scenes/entities/npc.tscn")
const VINE_SCENE := preload("res://scenes/entities/shadow_vine.tscn")
const MIRROR_SCENE := preload("res://scenes/entities/mirror.tscn")
const SHARD_SCENE := preload("res://scenes/entities/star_shard.tscn")
const CHECKPOINT_SCENE := preload("res://scenes/entities/checkpoint.tscn")
const EXIT_SCENE := preload("res://scenes/entities/exit.tscn")
const WORMHOLE_SCENE := preload("res://scenes/entities/wormhole.tscn")
const CRACKED_SCENE := preload("res://scenes/entities/cracked_wall.tscn")
const IRON_DOOR_SCENE := preload("res://scenes/entities/iron_door.tscn")
const BARS_SCENE := preload("res://scenes/entities/bars.tscn")
const TILES := preload("res://data/tiles.tres")

## 测试场景自己当章节根，save_id 是 "t/…"。
var chapter_id := &"t"

var _failures := 0
var _player: Player
var _nodes: Array[Node] = []
var _events: Array = []

func _init() -> void:
	add_to_group(&"chapter")

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	for sig in [Game.npc_rescued, Game.vine_burnt, Game.checkpoint_reached, Game.chapter_cleared, Game.wall_broken]:
		sig.connect(func(a = null, _b = null) -> void: _events.append([sig.get_name(), a]))
	Game.warped.connect(func() -> void: _events.append([&"warped", _player.velocity]))
	_pure_checks()
	var finished: Variant = await _cases()
	_check("所有用例都跑完了", finished == true)
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])

func _pure_checks() -> void:
	var t := Game.tuning
	_check("亮度 60 时散射半径约 145.7", is_equal_approx(t.scatter_radius(60.0), 90.0 + 130.0 * 60.0 / 140.0), "%.1f" % t.scatter_radius(60.0))
	_check("聚光距离 = 散射半径 × 2.2", is_equal_approx(t.focus_range(60.0), t.scatter_radius(60.0) * 2.2))
	var npc := NPC_SCENE.instantiate()
	var entities := Node.new()
	entities.name = "Entities"
	add_child(entities)
	npc.name = "Foo"
	entities.add_child(npc)
	_check("save_id = 章节/路径", npc.save_id == "t/Entities/Foo", npc.save_id)
	entities.free()

func _cases() -> bool:
	# 散射：范围内照满 wake_time 就得救，上限 +5 并回满。
	await _begin()
	var npc := _npc(Vector2(100, 0))
	await _frames(110)
	_check("散射照 1.8 秒：还在醒来中", npc.state == Npc.State.WAKING, "进度 %.2f" % npc.progress)
	await _frames(20)
	_check("散射照满 2 秒：得救并存档", npc.state == Npc.State.RESCUED and Save.rescued.has(npc.save_id))
	_check("救人后亮度上限 +5 并回满", _player.light_max == 65.0 and _player.light == 65.0, "%.1f / %.1f" % [_player.light, _player.light_max])
	_check("npc_rescued 只发一次", _count(&"npc_rescued") == 1)

	await _begin()
	npc = _npc(Vector2(200, 0))
	await _frames(60)
	_check("散射半径外照不到", npc.state == Npc.State.CRYING and npc.progress == 0.0)

	await _begin()
	_walls(Rect2i(1, -3, 1, 7))
	npc = _npc(Vector2(100, 0))
	await _frames(60)
	_check("隔着墙照不到", npc.state == Npc.State.CRYING)

	await _begin()
	npc = _npc(Vector2(100, 0))
	await _frames(60)
	_player.light_mode = Player.LightMode.FOCUS
	_player.aim = Vector2.LEFT
	await _frames(20)
	var mid := npc.progress
	await _frames(20)
	_check("没照到时进度按 2 倍回落，归零后重新哭", mid > 0.2 and mid < 0.45 and npc.state == Npc.State.CRYING, "20 帧后 %.2f" % mid)

	# 聚光：锥形内、距离内才算；背后的光环不算。
	await _begin(Player.LightMode.FOCUS)
	npc = _npc(Vector2(250, 0))
	var off := _npc(Vector2.from_angle(deg_to_rad(30.0)) * 250.0)
	var behind := _npc(Vector2(-60, 0))
	await _frames(130)
	_check("聚光照到散射半径外的目标", npc.state == Npc.State.RESCUED)
	_check("偏出锥形 30° 照不到", off.state == Npc.State.CRYING)
	_check("聚光时背后的光环不照亮", behind.state == Npc.State.CRYING)

	# 影藤：聚光 1.5 秒烧断，挡在后面的小人随后能照到；散射烧不动。
	await _begin(Player.LightMode.FOCUS)
	var vine := _vine(Vector2(150, 0), Vector2(32, 96))
	var vine_id := vine.save_id
	npc = _npc(Vector2(220, 0))
	await _frames(60)
	_check("影藤挡住后面的小人", npc.state == Npc.State.CRYING and is_instance_valid(vine) and vine.state == ShadowVine.State.BURNING)
	await _frames(40)
	_check("聚光 1.5 秒烧断影藤并存档", not is_instance_valid(vine) and Save.burnt.has(vine_id) and _count(&"vine_burnt") == 1)
	await _frames(10)
	_check("影藤烧断后后面的小人照得到", npc.state == Npc.State.WAKING)

	await _begin()
	vine = _vine(Vector2(100, 0), Vector2(32, 96))
	await _frames(120)
	_check("散射烧不动影藤", is_instance_valid(vine) and vine.state == ShadowVine.State.INTACT and vine.burn == 0.0)

	# 玻璃：中心射线打到 / 玻璃，光往上拐，照到上面的小人；换成 \ 玻璃就往下拐，照不到。
	await _begin(Player.LightMode.FOCUS)
	_mirror(Vector2(128, 0), -PI / 4.0)
	npc = _npc(Vector2(128, -128))
	await _frames(130)
	_check("聚光经玻璃反射照到拐角后的小人", npc.state == Npc.State.RESCUED)

	await _begin(Player.LightMode.FOCUS)
	_mirror(Vector2(128, 0), PI / 4.0)
	npc = _npc(Vector2(128, -128))
	await _frames(130)
	_check("反射方向不对就照不到", npc.state == Npc.State.CRYING)

	# 结伴：两人同时被照到才涨，满 pair_time 一起得救。
	await _begin()
	var q := _npc(Vector2(80, 0))
	var p := _npc(Vector2(-80, 0), {"partner": NodePath("../" + q.name)})
	await _frames(100)
	_check("结伴：两人同时照 1.5 秒一起得救", p.state == Npc.State.RESCUED and q.state == Npc.State.RESCUED and _count(&"npc_rescued") == 2)

	await _begin()
	q = _npc(Vector2(250, 0))
	p = _npc(Vector2(-80, 0), {"partner": NodePath("../" + q.name)})
	await _frames(120)
	_check("结伴：只照到一人不涨", p.state == Npc.State.CRYING and q.state == Npc.State.CRYING)

	# 职业：救下后存档记下职业，梦想浮现。
	await _begin()
	npc = _npc(Vector2(100, 0), {"role": "clockmaker"})
	await _frames(130)
	_check("救下后存档记下职业", Save.rescued.get(npc.save_id) == &"clockmaker" and Save.has_role(&"clockmaker"))

	# 藏着的人：向导被救之前听不见，照到照样能救。
	await _begin()
	var secret := _npc(Vector2(-100, 0), {"secret": true, "role": "postman"})
	var guide := _npc(Vector2(250, 0), {"role": "guide"})
	await _frames(2)
	_check("藏着的人：向导被救之前听不见哭声", not secret.is_heard())
	_player.light_mode = Player.LightMode.FOCUS
	await _frames(130)
	_check("藏着的人：向导被救后听得见", guide.state == Npc.State.RESCUED and secret.is_heard() and secret.state == Npc.State.CRYING)
	_player.light_mode = Player.LightMode.SCATTER
	await _frames(130)
	_check("藏着的人照到照样能救", secret.state == Npc.State.RESCUED)

	# 照不到的人：小星的光不算数，邮差被救时一起被救，不在场的只记进存档。
	await _begin()
	var doctor := _npc(Vector2(100, 0), {"mail": true, "role": "doctor"})
	Save.mail["t/Far/Away"] = &"listener"
	await _frames(130)
	_check("照不到的人：照满 2 秒也不算，登记在等邮差的名单里", doctor.state == Npc.State.CRYING and Save.mail.has(doctor.save_id))
	var postman := _npc(Vector2(-100, 0), {"role": "postman"})
	await _frames(130)
	_check("邮差被救：在场的照不到的人一起被救", postman.state == Npc.State.RESCUED and doctor.state == Npc.State.RESCUED and Save.rescued.get(doctor.save_id) == &"doctor")
	_check("邮差被救：不在场的也记成已救，亮度上限跟着涨", Save.rescued.get("t/Far/Away") == &"listener" and _player.light_max == 60.0 + 3 * 5.0, "上限 %.0f" % _player.light_max)

	# 锁匠：被救时铁门当场打开；之后加载的铁门直接不出现。
	await _begin()
	var door := _add(IRON_DOOR_SCENE.instantiate(), Vector2(0, 200)) as IronDoor
	_npc(Vector2(100, 0), {"role": "locksmith"})
	await _frames(10)
	_check("锁匠没救：铁门关着", is_instance_valid(door) and door.state == IronDoor.State.CLOSED)
	await _frames(125)
	_check("锁匠被救：铁门当场打开", not is_instance_valid(door))
	var later := _add(IRON_DOOR_SCENE.instantiate(), Vector2(0, 300))
	await _frames(2)
	_check("锁匠已救：之后加载的铁门直接不出现", not is_instance_valid(later))

	# 栅栏：挡人不挡光。
	await _begin()
	var bars := BARS_SCENE.instantiate() as Bars
	bars.size = Vector2(32, 160)
	_add(bars, Vector2(60, 0))
	npc = _npc(Vector2(110, 0))
	await _frames(130)
	_check("隔着栅栏照得到", npc.state == Npc.State.RESCUED)

	# 小星星：回 15，不超过上限。
	await _begin()
	_add(SHARD_SCENE.instantiate(), Vector2(60, 0))
	_player.light = 30.0
	_player.velocity = Vector2(200, 0)
	await _frames(30)
	_check("小星星回 15 亮度", is_equal_approx(_player.light, 45.0), "%.1f" % _player.light)

	await _begin()
	_add(SHARD_SCENE.instantiate(), Vector2(60, 0))
	_player.light = 55.0
	_player.velocity = Vector2(200, 0)
	await _frames(30)
	_check("小星星回亮度不超过上限", _player.light == _player.light_max, "%.1f" % _player.light)

	# 聚光衰减更快。
	await _begin()
	Game.debug_no_decay = false
	await _frames(60)
	var scatter_loss := 60.0 - _player.light
	_player.light_mode = Player.LightMode.FOCUS
	var before := _player.light
	await _frames(60)
	var focus_loss := before - _player.light
	Game.debug_no_decay = true
	_check("散射每秒衰减 1，聚光每秒衰减 1.5", absf(scatter_loss - 1.0) < 0.05 and absf(focus_loss - 1.5) < 0.05, "%.2f / %.2f" % [scatter_loss, focus_loss])

	# 检查点。
	await _begin()
	var cp := _add(CHECKPOINT_SCENE.instantiate(), Vector2(60, 0)) as Checkpoint
	_player.velocity = Vector2(200, 0)
	await _frames(30)
	_check("进入检查点：记进存档并点亮", Save.checkpoint == cp.save_id and cp.state == Checkpoint.State.ACTIVE and _count(&"checkpoint_reached") == 1)

	# 出口：一直开着，一个人都没救也能进，进入后发 chapter_cleared。
	await _begin()
	var exit := _add(EXIT_SCENE.instantiate(), Vector2(260, 0)) as Exit
	_npc(Vector2(-200, 0))
	_player.velocity = Vector2(300, 0)
	await _frames(60)
	_check("一个都没救也能进出口，发 chapter_cleared", exit.state == Exit.State.CLEARED and _count(&"chapter_cleared") == 1 and Save.rescued.is_empty())

	# 虫洞：速率和方向不变地从另一端出来，冷却期内不会马上传回去。
	await _begin()
	var worm := _wormhole(Vector2(100, 0), Vector2(600, 300))
	_player.velocity = Vector2(300, 0)
	var entry := await _until_warp()
	await _frames(12)
	var arrival: Vector2 = _events.filter(func(e: Array) -> bool: return e[0] == &"warped")[0][1]
	_check("虫洞：从 B 前面出来", _player.state == Player.State.ACTIVE and _player.global_position.distance_to(Vector2(600 + Wormhole.PUSH, 300)) < 30.0, "%s" % _player.global_position)
	_check("虫洞：出来时速度和进去时一样", arrival.distance_to(entry) < 2.0, "%s → %s" % [entry, arrival])
	_check("虫洞：发 warped", _count(&"warped") == 1)
	_player.velocity = Vector2(-300, 0)
	await _frames(6)
	_check("虫洞：冷却期内回到 B 不会传送", _player.global_position.x > 500.0 and _count(&"warped") == 1, "%s" % _player.global_position)
	worm.free()

	await _begin()
	worm = _wormhole(Vector2(100, 0), Vector2(600, 300), false)
	(worm.get_node("B") as Node2D).rotation = PI / 2.0
	_player.velocity = Vector2(300, 0)
	entry = await _until_warp()
	await _frames(12)
	arrival = _events.filter(func(e: Array) -> bool: return e[0] == &"warped")[0][1]
	_check("虫洞 keep_direction 为假：方向改成出口朝向，速率不变", arrival.normalized().is_equal_approx(Vector2.DOWN) and absf(arrival.length() - entry.length()) < 2.0, "%s → %s" % [entry, arrival])

	# 读存档：已救、已烧、已碎的直接是最终状态。
	await _begin()
	Save.rescued["t/Saved"] = &"none"
	Save.burnt["t/Burnt"] = true
	Save.broken["t/Broken"] = true
	npc = _npc(Vector2(300, 300), {}, "Saved")
	vine = _vine(Vector2(300, 400), Vector2(32, 32), "Burnt")
	var crack := CRACKED_SCENE.instantiate()
	crack.name = "Broken"
	_add(crack, Vector2(300, 500))
	await _frames(2)
	_check("存档里已救的小人直接是得救状态，不发信号", npc.state == Npc.State.RESCUED and _count(&"npc_rescued") == 0)
	_check("存档里已烧的影藤、已碎的裂纹墙不再出现", not is_instance_valid(vine) and not is_instance_valid(crack))

	await _begin()
	crack = CRACKED_SCENE.instantiate()
	_add(crack, Vector2(300, 0))
	var crack_id: String = crack.save_id
	crack.smash()
	_check("裂纹墙撞碎：存档并发 wall_broken", Save.broken.has(crack_id) and _count(&"wall_broken") == 1)
	await _end()
	return true

## 每个用例重新开始：清存档、清信号记录，在原点放一个散射（或聚光）、朝右的小星。
func _begin(mode := Player.LightMode.SCATTER) -> void:
	await _end()
	Save.clear()
	Game.debug_no_decay = true
	_events.clear()
	_player = PLAYER_SCENE.instantiate() as Player
	_player.aim_from_mouse = false
	_add(_player, Vector2.ZERO)
	while _player.state != Player.State.ACTIVE:
		await get_tree().physics_frame
	_player.light_mode = mode
	_player.aim = Vector2.RIGHT

func _end() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	await _frames(2)

func _add(node: Node2D, pos: Vector2) -> Node2D:
	node.position = pos
	add_child(node)
	_nodes.append(node)
	return node

func _npc(pos: Vector2, props := {}, name := "") -> Npc:
	var npc := NPC_SCENE.instantiate() as Npc
	if name != "":
		npc.name = name
	for key in props:
		npc.set(key, props[key])
	return _add(npc, pos) as Npc

func _vine(pos: Vector2, size: Vector2, name := "") -> ShadowVine:
	var vine := VINE_SCENE.instantiate() as ShadowVine
	if name != "":
		vine.name = name
	vine.size = size
	return _add(vine, pos) as ShadowVine

func _mirror(pos: Vector2, angle: float) -> Mirror:
	var mirror := MIRROR_SCENE.instantiate() as Mirror
	mirror.rotation = angle
	mirror.length = 60.0
	return _add(mirror, pos) as Mirror

func _walls(cells: Rect2i) -> void:
	var layer := TileMapLayer.new()
	layer.tile_set = TILES
	for x in range(cells.position.x, cells.end.x):
		for y in range(cells.position.y, cells.end.y):
			layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	_add(layer, Vector2.ZERO)

func _wormhole(a: Vector2, b: Vector2, keep := true) -> Wormhole:
	var worm := WORMHOLE_SCENE.instantiate() as Wormhole
	worm.keep_direction = keep
	(worm.get_node("A") as Node2D).position = a
	(worm.get_node("B") as Node2D).position = b
	return _add(worm, Vector2.ZERO) as Wormhole

## 跑到小星进入虫洞为止，返回进去前一帧的速度。
func _until_warp() -> Vector2:
	var before := _player.velocity
	for i in 60:
		if _player.state == Player.State.WARP:
			break
		before = _player.velocity
		await get_tree().physics_frame
	return before

func _count(kind: StringName) -> int:
	return _events.filter(func(e: Array) -> bool: return e[0] == kind).size()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
