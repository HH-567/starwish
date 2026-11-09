extends Control
## 星星齿轮图标：齿轮外圈 + 中间一颗四角星，点一下开设置。
## 画出来的，不需要贴图。

signal pressed

const SIZE := 44.0
const TEETH := 8
const IDLE := Color("b9c8ff", 0.75)
const HOT := Color("ffd75a")

var _hover := false

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hover = false; queue_redraw())

func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()

func _draw() -> void:
	var c := HOT if _hover else IDLE
	var center := size * 0.5
	var r := SIZE * 0.32
	# 齿轮：一圈方块齿
	for i in TEETH:
		var a := TAU * float(i) / float(TEETH)
		var p := center + Vector2.from_angle(a) * r
		var t := Vector2(6.0, 6.0)
		draw_rect(Rect2(p - t * 0.5, t), c)
	draw_arc(center, r, 0.0, TAU, 32, c, 2.0, true)
	draw_arc(center, r * 0.62, 0.0, TAU, 24, Color(c, 0.55), 1.5, true)
	# 中间的四角星
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0 - PI / 2.0
		var rr := r * 0.62 if i % 2 == 0 else r * 0.24
		pts.append(center + Vector2.from_angle(a) * rr)
	draw_colored_polygon(pts, c)
