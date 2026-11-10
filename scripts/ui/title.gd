class_name Title
extends Control
## 标题：新的旅程 / 继续（有存档才出现）。已有进度时，"新的旅程"要按两次，免得误按把存档清掉。
## 背景是慢慢闪的星空，标题上方一颗发光的小星。
## 鼠标在窗口里移动时，画面按远近分层错开一点再弹回来（视差 + 弹簧回弹）；
## 没人动鼠标（纯键盘、触屏、headless）时画面完全静止。

const BG := Color("070b18")
const STAR := Color("ffd75a")
const SUB := Color("b9c8ff")
## 视差：鼠标推到屏幕角落时这一层移动多少像素。越靠前（越近）的层挪得越多。
const SWAY_STAR_DUST := 8.0
const SWAY_SKY := 17.0
const SWAY_GROUND := 25.0
const SWAY_BOSS := 14.0
const SWAY_PROPS := 36.0
const SWAY_FLIGHT := 21.0
## 弹簧：刚度越大跟得越快，阻尼略小会回弹一下（"晃"的那一下）。
const SWAY_STIFFNESS := 46.0
const SWAY_DAMPING := 6.5
## 鼠标划得越快，额外多带一下画面（菜单按钮都在正中，只靠位置几乎看不出晃）。
const SWAY_KICK := 8.0
## 一次鼠标事件最多按划了多远算（0..1 的屏幕比例），防止瞬移把画面甩出去。
const SWAY_KICK_STEP := 0.25
## 弹簧最多能推到的幅度（1 = 屏幕角落），留点余量给回弹。
const SWAY_LIMIT := 1.35
## 底色和地面往外多画这么多，某层挪开时不会露出边。
const SWAY_PAD := 56.0

var _stars: Array[Vector3] = []
var _t := 0.0
var _new: Button
var _continue: Button
var _confirm := false
## 真结局（隐藏结局）达成之后，标题才会亮起来、城市才出现、噬光者消失。
var _lit := false
## 0 → 1：标题停留期间光线慢慢升起来。
var _dawn := 0.0
## 鼠标离屏幕中心多远（-1..1，两轴）。各层的位移 = 它 × 这一层的深度。
var _sway := Vector2.ZERO
var _sway_v := Vector2.ZERO
## 鼠标此刻的位置（同样 -1..1）；弹簧朝它收。
var _sway_target := Vector2.ZERO
## 上一次鼠标位置（视口坐标）。用来算"这一下划了多远"，给弹簧加冲量。
var _mouse_last := Vector2.ZERO
var _mouse_seen := false

func _ready() -> void:
	Game.enter_title()
	Audio.play_bgm(&"title")
	Audio.set_ducked(false)
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
	_step_sway(delta)
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

## 鼠标在窗口里移动就朝它偏：离中心越远推得越多，移出窗口时回中。
## 划得快的那几下再额外给弹簧一个冲量，所以按钮附近小幅晃动也看得出来。
## 事件坐标是视口坐标；标题铺满视口、原点在 (0,0)，所以和这个控制的局部坐标一样。
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_to((event as InputEventMouseMotion).position)
	elif event is InputEventScreenDrag:
		_mouse_to((event as InputEventScreenDrag).position)

## 当前视差偏移（-1..1，两轴）。测试和截图读它，别直接碰私有字段。
func sway() -> Vector2:
	return _sway

func _mouse_to(pos: Vector2) -> void:
	if _mouse_seen:
		# 这一小段划多远：位移越大，画面被带得越多（和视差同一个方向，等于多带了一段惯性）。
		# 单次位移封顶，免得鼠标瞬移（窗口刚出现、传送）把画面一下甩出去。
		var step := ((pos - _mouse_last) / size.max(Vector2.ONE)).limit_length(SWAY_KICK_STEP)
		_sway_v += step * SWAY_KICK
	_mouse_last = pos
	_mouse_seen = true
	_point_at(pos)

## pos：控制内坐标。左上角 (-1,-1)、中心 (0,0)、右下角 (1,1)；窗口外当 0。
func _point_at(pos: Vector2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var d := pos / size - Vector2(0.5, 0.5)
	if absf(d.x) > 0.5 or absf(d.y) > 0.5:
		_sway_target = Vector2.ZERO
		return
	_sway_target = (d * 2.0).limit_length(1.0)

## 阻尼弹簧：目标一变，画面先冲过头再荡回来，最后停在目标上。
func _step_sway(delta: float) -> void:
	var acc := (_sway_target - _sway) * SWAY_STIFFNESS - _sway_v * SWAY_DAMPING
	_sway_v += acc * delta
	_sway += _sway_v * delta
	# 到头就别再往外冲了，把速度也清掉，否则会贴着边界卡一下。
	if absf(_sway.x) > SWAY_LIMIT:
		_sway.x = signf(_sway.x) * SWAY_LIMIT
		_sway_v.x = 0.0
	if absf(_sway.y) > SWAY_LIMIT:
		_sway.y = signf(_sway.y) * SWAY_LIMIT
		_sway_v.y = 0.0

## 视差：方向和鼠标相反（像镜头跟着视线转），近的层挪得多、远的层挪得少。
func _begin_layer(depth: float) -> void:
	draw_set_transform(-_sway * depth)

func _end_layer() -> void:
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	var pad := SWAY_PAD
	draw_rect(Rect2(-pad, -pad, size.x + pad * 2.0, size.y + pad * 2.0), BG)
	_begin_layer(SWAY_STAR_DUST)
	for s in _stars:
		draw_circle(Vector2(s.x, s.y) * size, 1.3, Color(1, 1, 1, 0.2 + 0.2 * sin(_t * 1.3 + s.z)))
	_draw_scene()
	_begin_layer(SWAY_FLIGHT)
	_draw_star_flight()
	_end_layer()

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

## 背景"游戏内容"：地砖、几盏路灯、站着的小人、几颗掉在地上的星屑、远处的噬光者。
## 全是剪影，不抢小星的气场。从前到后分四层，各自按视差挪一点。
func _draw_scene() -> void:
	var w := size.x
	var h := size.y
	var floor_y := h * 0.82
	# 地面：最近的一层。往上多铺一截，天际线相对它挪开时不会露缝。
	_begin_layer(SWAY_GROUND)
	var edge := 14.0
	draw_rect(Rect2(-SWAY_PAD, floor_y - edge, w + SWAY_PAD * 2.0,
		h - floor_y + edge + SWAY_PAD), Color(0.045, 0.05, 0.09))
	for row in 2:
		var y := floor_y + row * 26.0
		var offset := 0.0 if row == 0 else 34.0
		for x in range(-1, int(w / 68.0) + 2):
			var bx := x * 68.0 + offset
			draw_rect(Rect2(bx, y, 62.0, 22.0), Color(0.07, 0.065, 0.10))
	# 郊区和城市：远一层。左右各多画一截，挪开以后边上不会空。
	_begin_layer(SWAY_SKY)
	_draw_suburb(-SWAY_PAD - 20.0, w * 0.46, floor_y)
	if _dawn > 0.01:
		_draw_city(w * 0.54, w + SWAY_PAD, floor_y, _dawn)
	# 噬光者：压在远处，只挪一点点
	_begin_layer(SWAY_BOSS)
	if _dawn < 0.99:
		var boss := Vector2(w * 0.80, h * 0.30)
		var a := 1.0 - _dawn
		for k in 5:
			draw_circle(boss, 90.0 - k * 12.0, Color(0.03, 0.02, 0.06, 0.55 * a))
		draw_arc(boss, 90.0, 0.0, TAU, 48, Color(0.35, 0.16, 0.46, 0.35 * a), 2.0, true)
		for side: float in [-1.0, 1.0]:
			draw_circle(boss + Vector2(26.0, side * 12.0), 4.0, Color(1.0, 0.35, 0.48, 0.55 * a))
	# 路灯、小人、星屑：最前面
	_begin_layer(SWAY_PROPS)
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
	_end_layer()

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
