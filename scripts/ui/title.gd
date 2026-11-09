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
	box.add_child(_spacer(250))
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
	# 小星一边向上飞、一边拖出一条渐隐的尾迹（标题这里不写字）
	var base := Vector2(size.x * 0.5, size.y * 0.30)
	var rise := fmod(_t * 44.0, 150.0)
	var head_at := base + Vector2(sin(_t * 0.9) * 9.0, -rise + 75.0)
	for i in 14:
		var k := float(i) / 13.0
		var tail := head_at + Vector2(sin(_t * 0.9 - k * 1.7) * 9.0 * k, k * 150.0)
		var a := (1.0 - k) * (1.0 - k) * 0.6
		_draw_star(tail, lerpf(10.0, 2.0, k), Color(STAR, a), _t * 0.5 - k * 0.6)
	for k in 4:
		draw_circle(head_at, 46.0 - k * 11.0, Color(STAR, 0.03 + k * 0.022))
	_draw_star(head_at, 18.0, STAR, _t * 0.5)

## 画一颗四角星（rot 让它慢慢转）
func _draw_star(at: Vector2, r: float, c: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0 - PI / 2.0 + rot
		pts.append(at + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.36))
	draw_colored_polygon(pts, c)
