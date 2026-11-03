extends Node
## 输入来源（docs/state-machines.md 第 14 节）：KBM ⇄ TOUCH。小星只读统一的 move、aim 两个值，
## 不关心是哪来的。触屏时虚拟摇杆把值写进这里，键鼠时留空、由小星直接读 Input。
## 收到触摸事件切到 TOUCH，按到键切回 KBM（有触摸屏的机器上也能用键鼠）。

var touch := false
## 左摇杆：-1..1，已经乘好方向。没在推就是 ZERO。
var move := Vector2.ZERO
## 右摇杆：瞄准方向，没在推就是 ZERO（这时小星朝移动方向）。
var aim := Vector2.ZERO
## 触屏的"切换光圈模式"按钮：按一次置 true，小星取走。
var _mode_request := false

func _ready() -> void:
	# 一开机就在触屏设备上（手机、平板）时直接进入触屏模式。
	touch = DisplayServer.is_touchscreen_available()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch = true
	elif event is InputEventKey:
		touch = false
	elif event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available():
		touch = false

## 点一下"光"按钮：请求切换散射/聚光。
func request_mode_toggle() -> void:
	_mode_request = true

## 小星每帧取一次：取走了就清空。
func take_mode_toggle() -> bool:
	var on := _mode_request
	_mode_request = false
	return on
