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
## 真结局（隐藏结局）达成之后，标题才会亮起来、城市才出现、噬光者消失。
var _lit := false
## 0 → 1：标题停留期间光线慢慢升起来。
var _dawn := 0.0

func _ready() -> void:
	Game.enter_title()
	Audio.play_bgm(&"title")
	_lit = Save.endings.get("hidden", false)
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
	# 制作名单放最下面：低亮度的名单图标，不抢主菜单
	var credits := IconButton.make(IconButton.Kind.LIST, "制作名单")
	credits.dim = true
	credits.pressed.connect(_open_credits)
	box.add_child(credits)
	(_continue if _continue.visible else _new).grab_focus()

func _open_credits() -> void:
	var panel := (load("res://scenes/ui/credits.tscn") as PackedScene).instantiate()
	add_child(panel)
	panel.closed.connect(func() -> void:
		if _new != null:
			_new.grab_focus())

func _open_settings() -> void:
	var panel := (load("res://scenes/ui/settings.tscn") as PackedScene).instantiate()
	add_child(panel)
	panel.closed.connect(func() -> void: if _new != null: _new.grab_focus())

func _process(delta: float) -> void:
	_dawn = minf(_dawn + (delta if _lit else -delta) * 0.35, 1.0)
	_dawn = maxf(_dawn, 0.0)
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

## 左边：郊区。低矮的坡屋顶房子 + 栅栏 + 光秃的树。
func _draw_suburb(x0: float, x1: float, ground: float) -> void:
	var base := Color(0.075, 0.085, 0.13)
	var roof := Color(0.10, 0.105, 0.16)
	var i := 0
	var x := x0 - 20.0
	while x < x1:
		var w := 84.0 + fmod(float(i) * 37.0, 46.0)
		var h := 52.0 + fmod(float(i) * 23.0, 26.0)
		var top := ground - h
		draw_rect(Rect2(x, top, w, h), base)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 8.0, top), Vector2(x + w + 8.0, top), Vector2(x + w * 0.5, top - 30.0)]), roof)
		# 一扇暖窗
		draw_rect(Rect2(x + w * 0.3, top + h * 0.35, 14.0, 14.0), Color(1.0, 0.85, 0.55, 0.22))
		x += w + 26.0
		i += 1
	# 栅栏
	var fy := ground - 18.0
	for k in int((x1 - x0) / 16.0):
		draw_rect(Rect2(x0 + k * 16.0, fy, 3.0, 18.0), Color(0.09, 0.095, 0.14))
	draw_rect(Rect2(x0, fy + 4.0, x1 - x0, 3.0), Color(0.09, 0.095, 0.14))
	# 两棵光秃的树
	for tx: float in [x0 + 120.0, x0 + 300.0]:
		draw_rect(Rect2(tx - 3.0, ground - 64.0, 6.0, 64.0), base)
		draw_line(Vector2(tx, ground - 52.0), Vector2(tx - 16.0, ground - 74.0), base, 3.0, true)
		draw_line(Vector2(tx, ground - 58.0), Vector2(tx + 18.0, ground - 80.0), base, 3.0, true)

## 右边：城市。高低错落的楼 + 点点亮窗 + 天线。
func _draw_city(x0: float, x1: float, ground: float, lit := 1.0) -> void:
	var base := Color(0.065, 0.075, 0.13)
	var i := 0
	var x := x0
	while x < x1:
		var w := 46.0 + fmod(float(i) * 31.0, 44.0)
		var h := 120.0 + fmod(float(i) * 57.0, 120.0)
		var top := ground - h
		draw_rect(Rect2(x, top, w, h), base)
		# 天台的灯 / 天线
		draw_rect(Rect2(x + w * 0.5 - 1.5, top - 16.0, 3.0, 16.0), base)
		draw_circle(Vector2(x + w * 0.5, top - 16.0), 2.0, Color(1.0, 0.3, 0.35, 0.5))
		# 亮窗（稀疏、微弱）
		var cols := int(w / 16.0)
		var rows := int(h / 20.0)
		for cx in cols:
			for cy in rows:
				if fmod(float(cx * 7 + cy * 3 + i * 5), 4.0) > 1.4:
					continue
				var win := 0.10 + 0.12 * float((cx * 3 + cy * 5 + i) % 3)
				draw_rect(Rect2(x + 8.0 + cx * 16.0, top + 12.0 + cy * 20.0, 8.0, 10.0),
					Color(1.0, 0.86, 0.6, win * (0.35 + 1.0 * lit)))
		x += w + 14.0
		i += 1

## 背景"游戏内容"：地砖、几盏路、站着的小人、几颗掉在地上的星屑、远处的噬光者。
## 全是剪影，不抢小星的气场。
func _draw_scene() -> void:
	var w := size.x
	var h := size.y
	var floor_y := h * 0.82
	draw_rect(Rect2(0.0, floor_y, w, h - floor_y), Color(0.045, 0.05, 0.09))
	for row in 2:
		var y := floor_y + row * 26.0
		var offset := 0.0 if row == 0 else 34.0
		for x in range(-1, int(w / 68.0) + 2):
			var bx := x * 68.0 + offset
			draw_rect(Rect2(bx, y, 62.0, 22.0), Color(0.07, 0.065, 0.10))
	# 郊区一直在；城市要等真结局之后才亮起来
	_draw_suburb(0.0, w * 0.46, floor_y)
	if _dawn > 0.01:
		_draw_city(w * 0.54, w, floor_y, _dawn)
	# 噬光者：没打真结局时压在右上角，打完之后随着天亮消失
	if _dawn < 0.99:
		var boss := Vector2(w * 0.80, h * 0.30)
		var a := 1.0 - _dawn
		for k in 5:
			draw_circle(boss, 90.0 - k * 12.0, Color(0.03, 0.02, 0.06, 0.55 * a))
		draw_arc(boss, 90.0, 0.0, TAU, 48, Color(0.35, 0.16, 0.46, 0.35 * a), 2.0, true)
		for side: float in [-1.0, 1.0]:
			draw_circle(boss + Vector2(26.0, side * 12.0), 4.0, Color(1.0, 0.35, 0.48, 0.55 * a))
	# 路灯：没天亮时是熄的（只有柱子），天亮后灯芯开始亮
	for i in 3:
		var lamp_pos := Vector2(w * (0.12 + 0.13 * i), floor_y - 46.0)
		draw_rect(Rect2(lamp_pos + Vector2(-2.0, 0.0), Vector2(4.0, 46.0)), Color(0.10, 0.10, 0.14))
		if _dawn > 0.02:
			draw_circle(lamp_pos, 16.0, Color(1.0, 0.85, 0.55, (0.05 + 0.02 * sin(_t * 2.0 + i)) * _dawn))
			draw_circle(lamp_pos, 4.5, Color(1.0, 0.88, 0.6, 0.6 * _dawn))
		else:
			draw_circle(lamp_pos, 4.0, Color(0.12, 0.13, 0.2))
	# 站着的小人：剪影用暗色
	var spots: Array[Vector2] = [
		Vector2(w * 0.06, floor_y + 10.0), Vector2(w * 0.13, floor_y + 34.0),
		Vector2(w * 0.27, floor_y + 22.0), Vector2(w * 0.35, floor_y + 42.0),
		Vector2(w * 0.68, floor_y + 16.0), Vector2(w * 0.74, floor_y + 40.0),
	]
	for i in spots.size():
		var at: Vector2 = spots[i]
		var up := i % 2 == 0
		var body := Color(0.10, 0.12, 0.21)
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-7, 12), at + Vector2(7, 12),
			at + Vector2(4.5, -4.0 if up else 0.0), at + Vector2(-4.5, -4.0 if up else 0.0)]), body)
		draw_circle(at + Vector2(0, -13.0 if up else -7.5), 5.5, body)
	# 地上的星屑：天亮后更亮一些
	for i in 5:
		var shard := Vector2(w * (0.18 + 0.15 * i), floor_y + 6.0 + 9.0 * float(i % 3))
		var glow := 0.35 + 0.35 * _dawn
		_draw_star(shard, 4.5, Color(1.0, 0.91, 0.63, glow + 0.15 * sin(_t * 3.0 + i)))

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
