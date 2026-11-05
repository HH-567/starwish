extends Node2D
## 影鬼测试：看见就瞄、瞄完开枪、弹幕撞墙反弹 3 次、打中小星掉亮度、
## 弹幕回头打中影鬼就把它打掉、小星贴上去也能撞散、躲在墙后面它就不开枪。
##   godot --headless --path . --fixed-fps 60 res://tests/test_enemy.tscn

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const ENEMY_SCENE := preload("res://scenes/entities/enemy.tscn")
const SHOT_SCENE := preload("res://scenes/entities/shot.tscn")
const WALL := Vector2(600, 300)

var _failures := 0
var _player: Player
var _wall: StaticBody2D
var _kills: Array[StringName] = []

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Save.clear()
	Game.enemy_killed.connect(func(reason: StringName) -> void: _kills.append(reason))
	_player = PLAYER_SCENE.instantiate() as Player
	_player.aim_from_mouse = false
	add_child(_player)
	while _player.state != Player.State.ACTIVE:
		await get_tree().physics_frame
	_wall = _make_wall(WALL, Vector2(32, 220))
	await _sees_and_fires()
	await _hides_behind_wall()
	await _shot_bounces()
	await _shot_expires()
	await _shot_hurts_player()
	await _shot_kills_enemy()
	await _player_crushes_enemy()
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _make_wall(at: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = at
	wall.collision_layer = Layers.WORLD
	wall.collision_mask = 0
	add_child(wall)
	Shapes.add_rect(wall, size)
	return wall

## 看得见就瞄、瞄完就开一枪。
func _sees_and_fires() -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = Vector2(300, 300)
	add_child(enemy)
	_player.global_position = Vector2(150, 300)
	_player.velocity = Vector2.ZERO
	# 先等到 AIM：红线出来了
	var aimed := false
	for i in 120:
		await get_tree().physics_frame
		if enemy.state == Enemy.State.AIM:
			aimed = true
			break
	_check("看见小星就进入瞄准", aimed)
	# 再等它开火
	var fired := false
	for i in 120:
		await get_tree().physics_frame
		if _shots().size() > 0:
			fired = true
			break
	_check("瞄完打出一发弹幕", fired)
	_check("弹幕朝小星那边飞", _shots().size() > 0 and _shots()[0].direction.x < -0.5)
	for shot in _shots():
		shot.queue_free()
	enemy.queue_free()
	await get_tree().physics_frame

## 躲到墙后面：不再有新弹幕。
func _hides_behind_wall() -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = Vector2(300, 300)
	add_child(enemy)
	# 墙在 (600,300)，小星躲在墙右边
	_player.global_position = Vector2(760, 300)
	_player.velocity = Vector2.ZERO
	var fired := false
	for i in 200:
		await get_tree().physics_frame
		if _shots().size() > 0:
			fired = true
			break
	_check("隔着墙不开枪", not fired)
	enemy.queue_free()
	for shot in _shots():
		shot.queue_free()
	await get_tree().physics_frame

## 撞墙反弹：方向翻过来，次数加一。
func _shot_bounces() -> void:
	var shot := SHOT_SCENE.instantiate() as Shot
	shot.direction = Vector2.RIGHT
	shot.speed = 600.0
	shot.global_position = Vector2(520, 300)
	add_child(shot)
	var flipped := false
	for i in 60:
		await get_tree().physics_frame
		if not is_instance_valid(shot):
			break
		if shot.direction.x < -0.5:
			flipped = true
			break
	_check("撞墙后反弹", flipped)
	_check("记了一次反弹", is_instance_valid(shot) and shot.bounces == 1, "次数 %d" % (shot.bounces if is_instance_valid(shot) else -1))
	shot.queue_free()
	await get_tree().physics_frame

## 弹满 3 次就熄灭：拿四面墙围一个小盒子，让它一直弹。
func _shot_expires() -> void:
	var box := Node2D.new()
	add_child(box)
	var size := Vector2(140, 140)
	var dirs: Array[Vector2] = [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
	for d in dirs:
		var w := StaticBody2D.new()
		w.position = Vector2(1000, 300) + d * (size.x * 0.5 + 8.0)
		w.collision_layer = Layers.WORLD
		w.collision_mask = 0
		box.add_child(w)
		Shapes.add_rect(w, Vector2(size.x + 32.0, 16.0) if d.y == 0.0 else Vector2(16.0, size.x + 32.0))
	var shot := SHOT_SCENE.instantiate() as Shot
	shot.direction = Vector2(1, 0.37).normalized()
	shot.speed = 600.0
	shot.global_position = Vector2(1000, 300)
	box.add_child(shot)
	var went := false
	for i in 240:
		await get_tree().physics_frame
		if not is_instance_valid(shot):
			went = true
			break
	_check("弹满 3 次后熄灭", went)
	box.queue_free()
	await get_tree().physics_frame

## 打中小星：掉 shot_damage 的亮度。
func _shot_hurts_player() -> void:
	_player.global_position = Vector2(900, 300)
	_player.velocity = Vector2.ZERO
	_player.hurt_left = 0.0
	_player.light = _player.light_max
	var before := _player.light
	var shot := SHOT_SCENE.instantiate() as Shot
	shot.direction = Vector2.RIGHT
	shot.speed = 400.0
	shot.global_position = Vector2(820, 300)
	add_child(shot)
	var peak := 0.0
	for i in 60:
		await get_tree().physics_frame
		peak = maxf(peak, _player.velocity.dot(Vector2.RIGHT))
	_check("弹幕打中小星，扣 shot_damage", is_equal_approx(_player.light, before - Game.tuning.shot_damage), "%.0f → %.0f" % [before, _player.light])
	_check("弹幕把小星往同一方向推开", peak > Game.tuning.shot_knockback * 0.5, "峰值 %.0f px/s" % peak)
	await get_tree().physics_frame

## 弹幕打中影鬼：那只阵亡。
func _shot_kills_enemy() -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = Vector2(1000, 900)
	add_child(enemy)
	await get_tree().physics_frame
	_kills.clear()
	var shot := SHOT_SCENE.instantiate() as Shot
	shot.direction = Vector2.RIGHT
	shot.speed = 600.0
	shot.global_position = Vector2(900, 900)
	add_child(shot)
	for i in 60:
		await get_tree().physics_frame
		if not is_instance_valid(enemy):
			break
	_check("弹幕打中影鬼，它死了", not is_instance_valid(enemy))
	_check("发的是 shot 死因", _kills.has(&"shot"), "%s" % [_kills])

## 小星直接撞上去：影鬼也死。
func _player_crushes_enemy() -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.position = Vector2(400, 900)
	add_child(enemy)
	await get_tree().physics_frame
	_kills.clear()
	_player.global_position = enemy.position
	for i in 20:
		await get_tree().physics_frame
		if not is_instance_valid(enemy):
			break
	_check("小星撞上去，影鬼死", not is_instance_valid(enemy))
	_check("发的是 charge 死因", _kills.has(&"charge"), "%s" % [_kills])

func _shots() -> Array[Shot]:
	var out: Array[Shot] = []
	for child in get_children():
		if child is Shot:
			out.append(child as Shot)
	return out

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
