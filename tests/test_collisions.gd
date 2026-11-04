extends Node2D
## 移动和撞墙规则的无头测试。在工程目录运行：
##   godot --headless --path . --fixed-fps 60 res://tests/test_collisions.tscn
## 每个用例把小星放在墙前，以给定速度撞过去，检查结果。全部通过时退出码为 0。

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const CRACKED_SCENE := preload("res://scenes/entities/cracked_wall.tscn")
const PAD_SCENE := preload("res://scenes/entities/pad.tscn")
const STRIP_SCENE := preload("res://scenes/entities/accel_strip.tscn")
const IRON_DOOR_SCENE := preload("res://scenes/entities/iron_door.tscn")
const BARS_SCENE := preload("res://scenes/entities/bars.tscn")
const TILES := preload("res://data/tiles.tres")
## 竖墙所在的格子列，像素 320–352。
const WALL_X := 10
const START := Vector2(270, 16)

var _failures := 0
var _player: Player
## 每次撞击记一条：[类型, 撞后速度, 撞后亮度]
var _hits: Array = []
## 当前用例里出现过的最高速率。
var _max_speed := 0.0

func _ready() -> void:
	# 测试里死亡不重载场景。
	Game.player_died.disconnect(Game._on_player_died)
	Game.player_hit.connect(_on_hit)
	Game.debug_no_decay = true
	_pure_checks()
	# 用例中途脚本报错时协程会提前结束，这里拿不到 true。
	var finished: Variant = await _wall_cases()
	_check("所有撞墙用例都跑完了", finished == true)
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _on_hit(kind: StringName) -> void:
	_hits.append([kind, _player.velocity, _player.light])

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])

func _pure_checks() -> void:
	var p := PLAYER_SCENE.instantiate() as Player
	var t := Game.tuning
	var dt := 1.0 / 60.0
	_check("回差：阶段 1 到 230 还是 1", p.stage_for(230.0, 1) == 1)
	_check("回差：阶段 1 到 245 升到 2", p.stage_for(245.0, 1) == 2)
	_check("回差：阶段 2 降到 215 就回 1", p.stage_for(215.0, 2) == 1)
	_check("回差：阶段 3 降到 455 还是 3", p.stage_for(455.0, 3) == 3)
	_check("回差：阶段 3 降到 445 才回 2", p.stage_for(445.0, 3) == 2)
	_check("回差：阶段 2 到 470 升到 3", p.stage_for(470.0, 2) == 3)
	_check("从静止直接到 800 是阶段 5", p.stage_for(800.0, 1) == 5)
	var braked := p.step_velocity(Vector2(300, 0), Vector2.LEFT, dt).length()
	_check("反向输入刹车", is_equal_approx(braked, 300.0 - t.accel * t.brake_mult * dt), "%.2f" % braked)
	var coasted := p.step_velocity(Vector2(300, 0), Vector2.ZERO, dt).length()
	_check("松手缓慢减速", is_equal_approx(coasted, 300.0 - t.coast_decel * dt), "%.2f" % coasted)
	var old_turn := t.turn_mult
	t.turn_mult = 2.0
	var turned := p.step_velocity(Vector2(300, 0), Vector2.UP, dt)
	t.turn_mult = old_turn
	_check("转弯倍率只放大垂直分量", is_equal_approx(turned.x, 300.0) and is_equal_approx(turned.y, -t.accel * 2.0 * dt), "%s" % turned)
	var free_run := p.step_velocity(Vector2(379, 0), Vector2.RIGHT, dt).length()
	_check("没有封顶：379 还能继续加速", is_equal_approx(free_run, 379.0 + t.accel * dt), "%.2f" % free_run)
	var limited := p.step_velocity(Vector2(755, 0), Vector2.RIGHT, dt).length()
	_check("WASD 最多推到阶段 4 的顶", is_equal_approx(limited, 759.0), "%.2f" % limited)
	var over := p.step_velocity(Vector2(900, 0), Vector2.RIGHT, dt).length()
	_check("超过 WASD 上限：按住也只会慢慢回落", is_equal_approx(over, 900.0 - t.overspeed_decay * dt), "%.2f" % over)
	var top := p.step_velocity(Vector2(1200, 0), Vector2.RIGHT, dt).length()
	_check("再快也不超过 max_speed", is_equal_approx(top, t.max_speed), "%.2f" % top)
	p.free()

func _wall_cases() -> bool:
	var wall: Node2D = _tile_column(0)
	var hit := await _launch(wall, 150.0)
	_check("阶段 1 撞墙：滑停，不扣亮度", _kind(hit) == &"bump" and hit[1].length() < 1.0 and hit[2] == 60.0, _fmt(hit))
	await _cleanup(wall)

	wall = _tile_column(0)
	hit = await _launch(wall, 300.0)
	_check("阶段 2 撞墙：扣亮度并弹开", _kind(hit) == &"hurt" and is_equal_approx(hit[2], 60.0 - Game.tuning.s2_damage) and hit[1].x < 0.0 and is_equal_approx(hit[1].length(), Game.tuning.s2_exit_speed), _fmt(hit))
	_check("阶段 2 撞墙后进入无敌", _player.hurt_left > 0.0)
	await _cleanup(wall)

	wall = _tile_column(0)
	hit = await _launch(wall, 300.0, 15.0)
	_check("阶段 2 撞墙且亮度不够：碎裂", _kind(hit) == &"shatter" and _player.state == Player.State.DYING, _fmt(hit))
	await _cleanup(wall)

	wall = _tile_column(0)
	hit = await _launch(wall, 300.0, 60.0, Vector2.RIGHT, START, func(p: Player) -> void: p.grace_left = 0.5)
	_check("反弹保护期内的阶段 2 撞墙按反弹处理", _kind(hit) == &"bounce" and hit[2] == 60.0, _fmt(hit))
	await _cleanup(wall)

	wall = _tile_column(0)
	hit = await _launch(wall, 520.0)
	_check("阶段 3 撞墙：反弹，不扣亮度", _kind(hit) == &"bounce" and hit[1].x < -360.0 and hit[2] == 60.0, _fmt(hit))
	await _cleanup(wall)

	wall = _tile_column(0)
	hit = await _launch(wall, 650.0)
	_check("阶段 4 撞黑墙：反弹", _kind(hit) == &"bounce", _fmt(hit))
	await _cleanup(wall)

	wall = _entity(CRACKED_SCENE)
	hit = await _launch(wall, 520.0)
	_check("阶段 3 撞裂纹墙：反弹，墙还在", _kind(hit) == &"bounce" and is_instance_valid(wall), _fmt(hit))
	await _cleanup(wall)

	wall = _entity(CRACKED_SCENE)
	hit = await _launch(wall, 650.0)
	await _frames(10)
	_check("阶段 4 撞裂纹墙：撞碎并穿过去", _kind(hit) == &"break" and not is_instance_valid(wall) and _player.position.x > 360.0 and _player.velocity.x > 500.0, _fmt(hit))
	await _cleanup(wall)

	wall = _entity(PAD_SCENE)
	hit = await _launch(wall, 650.0)
	_check("阶段 4 撞软垫：急停，不扣亮度", _kind(hit) == &"stop" and hit[1] == Vector2.ZERO and hit[2] == 60.0, _fmt(hit))
	await _cleanup(wall)

	wall = _tile_column(0)
	hit = await _launch(wall, 850.0)
	await _frames(10)
	_check("阶段 5 撞黑墙：擦掉格子并穿过去", _kind(hit) == &"smash" and (wall as TileMapLayer).get_cell_source_id(Vector2i(WALL_X, 0)) == -1 and _player.position.x > 360.0, _fmt(hit))
	await _cleanup(wall)

	wall = _tile_column(1)
	hit = await _launch(wall, 850.0)
	_check("阶段 5 撞边界：反弹，格子还在", _kind(hit) == &"bounce" and (wall as TileMapLayer).get_cell_source_id(Vector2i(WALL_X, 0)) == 1, _fmt(hit))
	await _cleanup(wall)

	wall = _tile_floor()
	hit = await _launch(wall, 304.0, 60.0, Vector2(300, 50), Vector2(100, 40))
	_check("阶段 2 斜着擦过地面：贴墙滑走，不扣亮度", hit.is_empty() and _player.light == 60.0 and absf(_player.velocity.y) < 1.0 and _player.velocity.x > 100.0, "v=%s" % _player.velocity)
	await _cleanup(wall)

	wall = _entity(STRIP_SCENE, Vector2(64, 320))
	await _launch(wall, 300.0)
	_check("加速带：顺着进入提到 target_speed，超过 WASD 上限", _max_speed > 900.0, "最高 %.0f" % _max_speed)
	await _cleanup(wall)

	wall = _entity(STRIP_SCENE, Vector2(64, 320))
	wall.set("target_speed", 1200.0)
	await _launch(wall, 300.0)
	_check("加速带：再快也不超过 max_speed", _max_speed <= Game.tuning.max_speed + 0.01, "最高 %.0f" % _max_speed)
	await _cleanup(wall)

	wall = _entity(IRON_DOOR_SCENE)
	hit = await _launch(wall, 850.0)
	_check("阶段 5 撞铁门：反弹，门还在", _kind(hit) == &"bounce" and is_instance_valid(wall), _fmt(hit))
	await _cleanup(wall)

	wall = _entity(BARS_SCENE)
	hit = await _launch(wall, 520.0)
	_check("栅栏挡住小星：阶段 3 反弹", _kind(hit) == &"bounce" and is_instance_valid(wall), _fmt(hit))
	await _cleanup(wall)

	wall = _entity(BARS_SCENE)
	hit = await _launch(wall, 850.0)
	_check("阶段 5 撞栅栏：撞碎", _kind(hit) == &"smash" and not is_instance_valid(wall), _fmt(hit))
	await _cleanup(wall)
	return true

## 放好墙和小星，出生结束后给定速度，最多跑 90 帧；返回第一次撞击记录，没撞到返回空数组。
func _launch(wall: Node2D, speed: float, light := 60.0, dir := Vector2.RIGHT, start := START, setup := Callable()) -> Array:
	add_child(wall)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = start
	add_child(_player)
	while _player.state != Player.State.ACTIVE:
		await get_tree().physics_frame
	_player.light = light
	_player.velocity = dir.normalized() * speed
	if setup.is_valid():
		setup.call(_player)
	_hits.clear()
	_max_speed = 0.0
	for i in 90:
		await get_tree().physics_frame
		_max_speed = maxf(_max_speed, _player.velocity.length())
		if not _hits.is_empty():
			break
	return _hits[0] if not _hits.is_empty() else []

## wall 不标类型：撞碎的墙已经释放，带类型的参数会直接报错。
func _cleanup(wall) -> void:
	if is_instance_valid(wall):
		wall.queue_free()
	_player.queue_free()
	await _frames(2)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## 一列竖墙，source 0 = 普通墙，1 = 边界。
func _tile_column(source: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = TILES
	for y in range(-6, 7):
		layer.set_cell(Vector2i(WALL_X, y), source, Vector2i.ZERO)
	return layer

## 一排地面，上沿在 y = 64。
func _tile_floor() -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = TILES
	for x in range(0, 60):
		layer.set_cell(Vector2i(x, 2), 0, Vector2i.ZERO)
	return layer

## 放在竖墙那一列的实体。
func _entity(scene: PackedScene, size := Vector2(32, 320)) -> Node2D:
	var node := scene.instantiate() as Node2D
	node.set("size", size)
	node.position = Vector2(WALL_X * 32 + 16, 16)
	return node

func _kind(hit: Array) -> StringName:
	return hit[0] if not hit.is_empty() else &""

func _fmt(hit: Array) -> String:
	if hit.is_empty():
		return "没有撞击"
	return "%s v=(%.0f, %.0f) 亮度 %.0f" % [hit[0], hit[1].x, hit[1].y, hit[2]]
