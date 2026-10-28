extends Node2D
## 启动场景：星空背景 + 主星 + 两行中文 UI。
## 文字全部用 Label，字体来自 res://theme.tres（项目主题），不要用 ThemeDB.fallback_font。

var _t := 0.0
var _touches := 0

@onready var _title: Label = $UI/Title
@onready var _sub: Label = $UI/Sub
@onready var _hint: Label = $UI/Hint

func _ready() -> void:
	_layout()
	get_viewport().size_changed.connect(_layout)
	print("BOOT_OK godot=%s platform=%s" % [Engine.get_version_info().string, OS.get_name()])
	print("BOOT_FONT %s" % _title.get_theme_font("font").resource_path)

func _layout() -> void:
	var vp := get_viewport_rect().size
	for node in [_title, _sub, _hint]:
		node.size = Vector2(vp.x, 80)
	_title.position = Vector2(0, vp.y * 0.5 - 250)
	_sub.position = Vector2(0, vp.y * 0.5 + 130)
	_hint.position = Vector2(0, vp.y * 0.5 + 180)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_bump(event.position)
	elif event is InputEventMouseButton and event.pressed:
		_bump(event.position)

func _bump(pos: Vector2) -> void:
	_touches += 1
	print("BOOT_INPUT x=%d y=%d n=%d" % [pos.x, pos.y, _touches])
	_hint.text = "已接收到 %d 次输入 · 触摸/鼠标链路正常" % _touches

func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color("070b18"))
	for i in 90:
		var p := Vector2(fmod(float(i) * 131.7, vp.x), fmod(float(i) * 71.3, vp.y))
		var tw := 0.25 + 0.45 * absf(sin(_t * 1.3 + float(i) * 0.7))
		draw_circle(p, 1.5, Color(1, 1, 1, tw))
	var c := vp * 0.5
	draw_circle(c, 96.0, Color(0.16, 0.21, 0.48))
	var pts := PackedVector2Array()
	for i in 10:
		var r := 86.0 if i % 2 == 0 else 36.0
		var a := _t * 0.6 + TAU * float(i) / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, Color("ffd75a"))
