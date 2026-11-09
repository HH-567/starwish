class_name IconButton
extends Button
## 菜单用的图标按钮：只画图形，不写字（和游戏"画面上不写字"一致）。
## 保留 Button 的焦点 / 键盘导航 / 点击语义。
##   ▶ 继续   ↻ 回到检查点   ✦⚙ 设置   ⌂ 回到标题   ✧ 新的旅程

enum Kind { PLAY, RESTART, GEAR, HOME, NEW, LIST, CLOSE }

const IDLE := Color("b9c8ff")
const HOT := Color("ffd75a")
const SIZE := 64.0

var kind := Kind.PLAY
## 低亮度：次要按钮（比如制作名单）用，不抢主菜单的注意力。
var dim := false

static func make(k: Kind, tooltip := "") -> IconButton:
	var b := IconButton.new()
	b.kind = k
	b.tooltip_text = tooltip
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(SIZE, SIZE)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(func() -> void: Audio.play(&"ui"))
	return b

func _draw() -> void:
	var c := HOT if (is_hovered() or has_focus()) else IDLE
	if dim and not (is_hovered() or has_focus()):
		c = Color(IDLE, 0.4)
	var m := size * 0.5
	var r := minf(size.x, size.y) * 0.34
	match kind:
		Kind.PLAY:
			draw_colored_polygon(PackedVector2Array([
				m + Vector2(-r * 0.55, -r), m + Vector2(r, 0.0), m + Vector2(-r * 0.55, r)]), c)
		Kind.RESTART:
			# 圆弧 + 箭头：回到检查点
			draw_arc(m, r, -PI * 0.35, PI * 1.25, 28, c, 3.0, true)
			var tip := m + Vector2.from_angle(-PI * 0.35) * r
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(r * 0.38, -r * 0.1), tip + Vector2(0.0, r * 0.5), tip + Vector2(-r * 0.42, r * 0.05)]), c)
		Kind.GEAR:
			# 星星齿轮
			for i in 8:
				var a := TAU * float(i) / 8.0
				draw_rect(Rect2(m + Vector2.from_angle(a) * r - Vector2(5, 5), Vector2(10, 10)), c)
			draw_arc(m, r, 0.0, TAU, 28, c, 2.0, true)
			var pts := PackedVector2Array()
			for i in 8:
				var a2 := TAU * float(i) / 8.0 - PI / 2.0
				var rr := r * 0.62 if i % 2 == 0 else r * 0.24
				pts.append(m + Vector2.from_angle(a2) * rr)
			draw_colored_polygon(pts, c)
		Kind.HOME:
			# 回到标题：小房子
			draw_colored_polygon(PackedVector2Array([
				m + Vector2(0, -r * 1.15), m + Vector2(r, -r * 0.1), m + Vector2(-r, -r * 0.1)]), c)
			draw_rect(Rect2(m + Vector2(-r * 0.62, -r * 0.1), Vector2(r * 1.24, r * 0.95)), c)
			draw_rect(Rect2(m + Vector2(-r * 0.16, r * 0.24), Vector2(r * 0.32, r * 0.6)), Color(0.04, 0.05, 0.1))
		Kind.CLOSE:
			draw_line(m + Vector2(-r, -r), m + Vector2(r, r), c, 4.0, true)
			draw_line(m + Vector2(r, -r), m + Vector2(-r, r), c, 4.0, true)
		Kind.LIST:
			# 名单：三条横线 + 前面的小圆点
			for i in 3:
				var y := m.y + (float(i) - 1.0) * r * 0.6
				draw_circle(Vector2(m.x - r * 0.7, y), r * 0.12, c)
				draw_rect(Rect2(m.x - r * 0.42, y - r * 0.07, r * 1.25, r * 0.14), c)
		Kind.NEW:
			# 新的旅程：一颗星 + 一点新光
			var pts2 := PackedVector2Array()
			for i in 8:
				var a3 := TAU * float(i) / 8.0 - PI / 2.0
				var rr2 := r if i % 2 == 0 else r * 0.28
				pts2.append(m + Vector2(-r * 0.15, r * 0.1) + Vector2.from_angle(a3) * rr2)
			draw_colored_polygon(pts2, c)
			draw_circle(m + Vector2(r * 0.85, -r * 0.85), r * 0.22, c)
			draw_arc(m + Vector2(r * 0.85, -r * 0.85), r * 0.38, 0.0, TAU, 12, Color(c, 0.5), 1.5, true)
