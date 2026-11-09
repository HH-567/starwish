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
	_draw_scene()
	_draw_star_flight()

## 背景"游戏内容"：地砖、几盏路、站着的小人、几颗掉在地上的星屑、远处的噬光者。
## 全是剪影，不抢小星的气场。
func _draw_scene() -> void:
	var w := size.x
	var h := size.y
	# 底部两层地砖（和游戏里的墙砖一个色系，只留最暗的一档）
	var floor_y := h * 0.82
	draw_rect(Rect2(0.0, floor_y, w, h - floor_y), Color(0.045, 0.05, 0.09))
	for row in 2:
		var y := floor_y + row * 26.0
		var offset := 0.0 if row == 0 else 34.0
		for x in range(-1, int(w / 68.0) + 2):
			var bx := x * 68.0 + offset
			draw_rect(Rect2(bx, y, 62.0, 22.0), Color(0.07, 0.065, 0.10))
	# 远处噬光者：一大团暗影 + 一圈紫边（很淡）
	var boss := Vector2(w * 0.80, h * 0.30)
	for k in 5:
		draw_circle(boss, 90.0 - k * 12.0, Color(0.03, 0.02, 0.06, 0.55))
	draw_arc(boss, 90.0, 0.0, TAU, 48, Color(0.35, 0.16, 0.46, 0.35), 2.0, true)
	for side: float in [-1.0, 1.0]:
		draw_circle(boss + Vector2(26.0, side * 12.0), 4.0, Color(1.0, 0.35, 0.48, 0.55))
	# 三盏路灯：灯柱 + 一点暖光
	for i in 3:
		var lamp_pos := Vector2(w * (0.12 + 0.13 * i), floor_y - 46.0)
		draw_rect(Rect2(lamp_pos + Vector2(-2.0, 0.0), Vector2(4.0, 46.0)), Color(0.10, 0.10, 0.14))
		draw_circle(lamp_pos, 16.0, Color(1.0, 0.85, 0.55, 0.05 + 0.02 * sin(_t * 2.0 + i)))
		draw_circle(lamp_pos, 4.5, Color(1.0, 0.88, 0.6, 0.65))
	# 站着的小人：几组剪影，靠地的、坐着的
	var spots: Array[Vector2] = [
		Vector2(w * 0.06, floor_y + 10.0), Vector2(w * 0.13, floor_y + 34.0),
		Vector2(w * 0.27, floor_y + 22.0), Vector2(w * 0.35, floor_y + 42.0),
		Vector2(w * 0.68, floor_y + 16.0), Vector2(w * 0.74, floor_y + 40.0),
	]
	# 剪影用暗色，不能用地上的亮色，不然会抢小星
	for i in spots.size():
		var at: Vector2 = spots[i]
		var up := i % 2 == 0
		var body := Color(0.10, 0.12, 0.21)
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-7, 12), at + Vector2(7, 12),
			at + Vector2(4.5, -4.0 if up else 0.0), at + Vector2(-4.5, -4.0 if up else 0.0)]), body)
		draw_circle(at + Vector2(0, -13.0 if up else -7.5), 5.5, body)
	# 地上散落的星屑
	for i in 5:
		var shard := Vector2(w * (0.18 + 0.15 * i), floor_y + 6.0 + 9.0 * float(i % 3))
		_draw_star(shard, 4.5, Color(1.0, 0.91, 0.63, 0.45 + 0.2 * sin(_t * 3.0 + i)))

## 小星：先往上飞，到顶再转弯飞下来，一圈一圈地绕着飞（椭圆的轨道 + 尾迹）
func _draw_star_flight() -> void:
	var center := Vector2(size.x * 0.50, size.y * 0.40)
	var rx := size.x * 0.20
	var ry := size.y * 0.17
	var phase := _t * 0.55
	# 尾迹：沿着同一条椭圆往回采样
	for i in 16:
		var k := float(i) / 15.0
		var a := phase - k * 1.15
		var tail := center + Vector2(cos(a) * rx, sin(a) * ry)
		var fade := (1.0 - k) * (1.0 - k)
		_draw_star(tail, lerpf(9.0, 1.8, k), Color(STAR, 0.55 * fade), a * 0.5)
	var head := center + Vector2(cos(phase) * rx, sin(phase) * ry)
	for k in 4:
		draw_circle(head, 42.0 - k * 10.0, Color(STAR, 0.03 + k * 0.022))
	_draw_star(head, 17.0, STAR, _t * 0.5)

## 画一颗四角星（rot 让它慢慢转）
func _draw_star(at: Vector2, r: float, c: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := TAU * float(i) / 8.0 - PI / 2.0 + rot
		pts.append(at + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.36))
	draw_colored_polygon(pts, c)
