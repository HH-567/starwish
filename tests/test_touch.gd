extends Node
## 触屏测试：触摸事件把输入来源切到 TOUCH、虚拟摇杆显示出来、左摇杆能推动小星、
## 右摇杆能改瞄准、"光"按钮能切散射/聚光、键鼠按一下切回 KBM。
##   godot --headless --path . --fixed-fps 60 res://tests/test_touch.tscn

const LEVEL := "res://scenes/levels/ch0_fall.tscn"

var _failures := 0
var _player: Player
var _touch: Control

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Save.clear()
	add_child((load(LEVEL) as PackedScene).instantiate())
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_player.aim_from_mouse = false
	_touch = _player.get_parent().get_node_or_null(^"HUD/Touch") as Control
	while _player.state != Player.State.ACTIVE:
		await get_tree().physics_frame

	_check("开局不是触屏模式（无头没有触摸屏）", not Controls.touch)
	_check("控件默认藏着", _touch != null and not _touch.visible)

	# 碰一下屏幕：切到触屏，摇杆出现。
	await _touch_at(Vector2(200, 600), 0, true)
	await _frames(2)
	_check("触摸后切到触屏模式", Controls.touch)
	_check("摇杆出现了", _touch.visible)

	# 左摇杆往右上推：小星往右上走。
	var before := _player.global_position
	await _touch_at(Vector2(200, 600), 0, true)
	await _drag_to(Vector2(280, 520), 0)
	await _frames(30)
	_check("左摇杆推出移动方向", Controls.move.length() > 0.5, "%s" % [Controls.move])
	_check("小星跟着往右上走", _player.global_position.x > before.x + 8.0 and _player.global_position.y < before.y - 8.0, "%s → %s" % [before, _player.global_position])

	# 右摇杆往左推：瞄准改朝左。
	await _touch_at(Vector2(900, 500), 1, true)
	await _drag_to(Vector2(820, 500), 1)
	await _frames(4)
	_check("右摇杆改瞄准", _player.aim.x < -0.9, "%s" % [_player.aim])

	# 松手：移动停、瞄准回到移动方向。
	await _touch_at(Vector2(280, 520), 0, false)
	await _touch_at(Vector2(820, 500), 1, false)
	await _frames(4)
	_check("松手后不再移动", Controls.move == Vector2.ZERO and Controls.aim == Vector2.ZERO)

	# "光"按钮：散射和聚光来回切。
	var mode := _player.light_mode
	(_touch.get_node(^"LightButton") as Button).pressed.emit()
	await _frames(4)
	_check("点光按钮：切换光圈模式", _player.light_mode != mode, "%d → %d" % [mode, _player.light_mode])

	# 按一下键：切回键鼠，摇杆收起。
	var key := InputEventKey.new()
	key.physical_keycode = KEY_A
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	_check("按键切回键鼠", not Controls.touch)
	_check("摇杆收起", not _touch.visible)

	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])

## 发一个触摸按下/抬起事件，坐标是控件内的位置。
func _touch_at(at: Vector2, index: int, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = at
	ev.pressed = pressed
	# 直接推进视口：parse_input_event 会被窗口缩放再换算一次，坐标就对不上了
	get_viewport().push_input(ev, true)
	await get_tree().process_frame

func _drag_to(at: Vector2, index: int) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = at
	# 直接推进视口：parse_input_event 会被窗口缩放再换算一次，坐标就对不上了
	get_viewport().push_input(ev, true)
	await get_tree().process_frame

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
