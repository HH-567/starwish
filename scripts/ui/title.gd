class_name Title
extends Control
## 标题：新的旅程 / 继续（有存档才出现）。已有进度时，"新的旅程"要按两次，免得误按把存档清掉。
## 背景是慢慢闪的星空，标题上方一颗发光的小星。

const BG := Color("070b18")
const STAR := Color("ffd75a")
const SUB := Color("b9c8ff")

var _stars: Array[Vector3] = []
var _t := 0.0
var _new: Button
var _continue: Button
var _confirm := false

func _ready() -> void:
	Game.enter_title()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	for i in 90:
		_stars.append(Vector3(randf(), randf(), randf() * TAU))
	var box := Menu.centered_column(self)
	box.add_child(_spacer(90))
	box.add_child(Menu.label("星愿", 96, STAR))
	box.add_child(Menu.label("撞碎长夜", 34, SUB))
	box.add_child(_spacer(40))
	_new = IconButton.make(IconButton.Kind.NEW, "新的旅程")
	_new.pressed.connect(_on_new)
	box.add_child(_new)
	var gear := IconButton.make(IconButton.Kind.GEAR, "设置")
	gear.pressed.connect(_open_settings)
	box.add_child(gear)
	_continue = IconButton.make(IconButton.Kind.PLAY, "继续")
	_continue.pressed.connect(_on_continue)
	_continue.visible = Game.can_continue()
	box.add_child(_continue)
	(_continue if _continue.visible else _new).grab_focus()

func _open_settings() -> void:
	var panel := (load("res://scenes/ui/settings.tscn") as PackedScene).instantiate()
	add_child(panel)
	panel.closed.connect(func() -> void: if _new != null: _new.grab_focus())

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _on_new() -> void:
	if Game.can_continue() and not _confirm:
		_confirm = true
		_new.kind = IconButton.Kind.RESTART
		_new.tooltip_text = "再按一次：从头开始"
		_new.queue_redraw()
		return
	_lock()
	Game.start_new()

func _on_continue() -> void:
	_lock()
	Game.continue_game()

## 开始以后按钮都不能再按，免得渐变途中又触发一次。
func _lock() -> void:
	_new.disabled = true
	_continue.disabled = true

func _spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	for s in _stars:
		draw_circle(Vector2(s.x, s.y) * size, 1.3, Color(1, 1, 1, 0.2 + 0.2 * sin(_t * 1.3 + s.z)))
	# 标题上方的小星：一圈光晕加一颗慢慢转的五角星。
	var c := Vector2(size.x * 0.5, size.y * 0.5 - 150.0)
	for k in 4:
		draw_circle(c, 60.0 - k * 12.0, Color(STAR, 0.04 + k * 0.03))
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(c + Vector2.from_angle(_t * 0.4 + TAU * i / 10.0 - PI / 2.0) * (22.0 if i % 2 == 0 else 9.0))
	draw_colored_polygon(pts, STAR)
