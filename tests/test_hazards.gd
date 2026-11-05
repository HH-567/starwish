extends Node2D
## P2 机关测试：流星预警后砸中圈里的小星（扣 s2_damage）、圈外不挨砸；黑洞把人往里吸、越近越强。
##   godot --headless --path . --fixed-fps 60 res://tests/test_hazards.tscn
## 空场景，没有墙。

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const METEOR_SCENE := preload("res://scenes/entities/meteor.tscn")
const HOLE_SCENE := preload("res://scenes/entities/blackhole.tscn")

var _failures := 0
var _player: Player
## 流星砸中过没有（信号回调写成员变量：lambda 捕获局部变量是按值拷的）。
var _meteor_hit := false

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Save.clear()
	Game.player_hit.connect(_on_hit)
	_player = PLAYER_SCENE.instantiate() as Player
	_player.aim_from_mouse = false
	add_child(_player)
	while _player.state != Player.State.ACTIVE:
		await get_tree().physics_frame

	await _meteor_hits_inside()
	await _meteor_misses_outside()
	await _blackhole_pulls()

	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _on_hit(kind: StringName) -> void:
	if kind == &"meteor":
		_meteor_hit = true

func _meteor_hits_inside() -> void:
	var meteor := METEOR_SCENE.instantiate() as Meteor
	meteor.position = Vector2(400, 300)
	add_child(meteor)
	_player.global_position = Vector2(400, 300)
	_player.velocity = Vector2.ZERO
	_player.light = _player.light_max
	_meteor_hit = false
	var before := _player.light
	# 一个间隔 + 预警，等它砸下来。
	for i in 400:
		await get_tree().physics_frame
		if _meteor_hit:
			break
	_check("流星砸中圈里的小星", _meteor_hit)
	_check("扣掉 s2_damage 的亮度", is_equal_approx(_player.light, before - Game.tuning.s2_damage), "%.0f → %.0f" % [before, _player.light])
	meteor.queue_free()
	await get_tree().physics_frame

func _meteor_misses_outside() -> void:
	_player.hurt_left = 0.0
	_player.light = _player.light_max
	_meteor_hit = false
	var meteor := METEOR_SCENE.instantiate() as Meteor
	meteor.position = Vector2(400, 300)
	add_child(meteor)
	# 站在判定半径外面（半径 + 小星半径 + 20）。
	_player.global_position = Vector2(400 + meteor.radius + Player.RADIUS + 20.0, 300)
	_player.velocity = Vector2.ZERO
	var before := _player.light
	for i in 400:
		await get_tree().physics_frame
	# 砸下来的事件照发（有落地声），但圈外不掉亮度。
	_check("圈外不挨砸", is_equal_approx(_player.light, before), "%.0f → %.0f" % [before, _player.light])
	meteor.queue_free()
	await get_tree().physics_frame

func _blackhole_pulls() -> void:
	var hole := HOLE_SCENE.instantiate() as BlackHole
	hole.position = Vector2(900, 300)
	hole.radius = 240.0
	add_child(hole)
	var center := hole.position
	# 距离 200 处放开 30 帧，看往里走了多少；80 处同样 30 帧，应该走得更远。
	var far_moved: float = await _drift(center + Vector2(200, 0), center, 30)
	var near_moved: float = await _drift(center + Vector2(80, 0), center, 30)
	_check("黑洞把半径里的人往里吸", far_moved > 2.0, "%.1f px" % far_moved)
	_check("越近吸得越强", near_moved > far_moved * 1.5, "远 %.1f px / 近 %.1f px" % [far_moved, near_moved])
	var outside: float = await _drift(center + Vector2(320, 0), center, 30)
	_check("半径外不受影响", absf(outside) < 1.0, "%.1f px" % outside)
	hole.queue_free()
	await get_tree().physics_frame

## 把人放在 at，跑 frames 帧，返回它朝 center 靠近了多少。
func _drift(at: Vector2, center: Vector2, frames: int) -> float:
	_player.global_position = at
	_player.velocity = Vector2.ZERO
	_player.push = Vector2.ZERO
	for i in frames:
		await get_tree().physics_frame
	return at.distance_to(center) - _player.global_position.distance_to(center)

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
