extends Node2D
## 死亡演出测试：小星一死就要"碎裂 + 特写 + 慢放"。
##   godot --headless --path . --fixed-fps 60 res://tests/test_death_fx.tscn

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")

var _failures := 0
var _player: Player
var _camera: Camera2D

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Save.clear()
	_player = PLAYER_SCENE.instantiate() as Player
	_player.aim_from_mouse = false
	add_child(_player)
	while _player.state != Player.State.ACTIVE:
		await get_tree().physics_frame
	_camera = _player.get_node(^"Camera") as Camera2D
	_player.global_position = Vector2(400, 300)

	# 把亮度一次打空：触发死亡
	_player.blast(_player.light_max * 2.0)
	_check("死了", _player.state == Player.State.DYING)
	await get_tree().process_frame
	var fx := _shatter()
	_check("碎了：场上有碎片特效", fx != null)
	_check("星体不再画出来、光开始暗下去", _player.fade() < 1.0, "fade=%.2f" % _player.fade())
	_check("慢放了", Engine.time_scale < 0.9, "time_scale=%.2f" % Engine.time_scale)
	_check("镜头还给了一次震动", _camera is Camera2D)

	# 特写：等一小会儿，镜头应该拉近（zoom.x 变大）
	var zoomed := false
	for i in 90:
		await get_tree().physics_frame
		if _camera != null and _camera.zoom.x > 1.1:
			zoomed = true
			break
	_check("镜头拉近做特写", zoomed, "zoom=%.2f" % (_camera.zoom.x if _camera != null else -1.0))

	# 特写结束要把慢放收回来
	var restored := false
	for i in 240:
		await get_tree().physics_frame
		if is_equal_approx(Engine.time_scale, 1.0):
			restored = true
			break
	_check("特写结束恢复常速", restored, "time_scale=%.2f" % Engine.time_scale)
	Engine.time_scale = 1.0

	# 第二种死法：亮度自己耗尽（熄灭）→ 化开，不是碎掉
	_player.queue_free()
	for child in get_children():
		if child is Shatter:
			child.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player = PLAYER_SCENE.instantiate() as Player
	_player.aim_from_mouse = false
	add_child(_player)
	while _player.state != Player.State.ACTIVE:
		await get_tree().physics_frame
	_player.global_position = Vector2(400, 300)
	_player._die(Player.Death.EXTINGUISHED)
	await get_tree().process_frame
	_check("熄灭：场上是消散特效", _dissolve() != null)
	_check("熄灭：没有碎片", _shatter() == null)
	_check("熄灭：星体还在画，慢慢淡下去", _player.fade() > 0.0, "fade=%.2f" % _player.fade())
	Engine.time_scale = 1.0
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _dissolve() -> Dissolve:
	for child in get_children():
		if child is Dissolve:
			return child as Dissolve
	return null

func _shatter() -> Shatter:
	for child in get_children():
		if child is Shatter:
			return child as Shatter
	return null

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
