extends Control
## 结局：被救的人化成一盏盏灯，一盏接一盏亮起来，然后浮出一行字。
## 正常结局"长夜暂退"；一个都没救就只有小星自己。隐藏结局"整座城都亮了"：先浮出噬光者体内找到的
## 电灯泡设计图（小星就是里面的灯丝），灯都亮完后整个画面暖起来。
## 灯都亮完一秒后，按任意键回标题；不按的话再过几秒自动回去。

const BG := Color("070b18")
## 隐藏结局最后的底色：天亮了。
const DAWN := Color("3a2c1c")
const LIGHT := Color("ffd98a")
const STAR := Color("ffd75a")
const BLUEPRINT := Color("9fd8ff")
## 两盏灯之间隔多久亮。
const STEP := 0.3
const AUTO_LEAVE := 8.0

var _count := 0
var _t := 0.0
var _left := false
var _words: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.play(&"ending")
	Audio.play_bgm(&"ending_hidden" if Game.ending == &"hidden" else &"ending_normal")
	_count = Save.rescued.size()
	_words = Menu.label("整座城都亮了" if Game.ending == &"hidden" else "长夜暂退", 40, Color("e8ecff"))
	_words.modulate.a = 0.0
	add_child(_words)

func _lit_time() -> float:
	return 0.8 + _count * STEP

func _process(delta: float) -> void:
	_t += delta
	# 字放在灯的弧线下面。
	_words.position = Vector2(0.0, size.y * 0.42 + 200.0)
	_words.size.x = size.x
	_words.modulate.a = clampf((_t - _lit_time()) / 1.2, 0.0, 1.0)
	if _t > _lit_time() + AUTO_LEAVE:
		_leave()
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed()
	if pressed and _t > _lit_time() + 1.0:
		_leave()

func _leave() -> void:
	if _left:
		return
	_left = true
	Game.to_title()

func _draw() -> void:
	var hidden := Game.ending == &"hidden"
	var dawn := clampf((_t - _lit_time()) / 2.0, 0.0, 1.0) if hidden else 0.0
	draw_rect(Rect2(Vector2.ZERO, size), BG.lerp(DAWN, dawn))
	var center := Vector2(size.x * 0.5, size.y * 0.42)
	if hidden:
		_draw_bulb(center, clampf(_t / 0.8, 0.0, 1.0))
	for k in 3:
		draw_circle(center, 34.0 - k * 9.0, Color(STAR, 0.06 + k * 0.05))
	draw_circle(center, 7.0, STAR)
	# 被救的人：沿着小星下方的弧线一盏盏亮起来。
	for i in _count:
		var a := clampf((_t - 0.8 - i * STEP) / 0.6, 0.0, 1.0)
		if a <= 0.0:
			continue
		var u := 0.5 if _count == 1 else float(i) / (_count - 1)
		var p := center + Vector2.from_angle(lerpf(PI * 0.85, PI * 0.15, u)) * Vector2(320.0, 150.0)
		draw_circle(p, 22.0 * a, Color(LIGHT, 0.12 * a))
		draw_circle(p, 11.0 * a, Color(LIGHT, 0.22 * a))
		draw_circle(p, 4.5, Color(LIGHT, a))

## 电灯泡设计图：玻璃泡、灯颈、螺口，旁边一根尺寸线。a = 淡入进度。
func _draw_bulb(c: Vector2, a: float) -> void:
	var line := Color(BLUEPRINT, 0.7 * a)
	var thin := Color(BLUEPRINT, 0.35 * a)
	var r := 46.0
	draw_arc(c, r, PI * 0.72, PI * 2.28, 48, line, 2.0, true)
	var left := c + Vector2.from_angle(PI * 0.72) * r
	var right := c + Vector2.from_angle(PI * 0.28) * r
	draw_line(left, c + Vector2(-16.0, 62.0), line, 2.0)
	draw_line(right, c + Vector2(16.0, 62.0), line, 2.0)
	for k in 3:
		var y := 64.0 + k * 7.0
		draw_line(c + Vector2(-15.0, y), c + Vector2(15.0, y), line, 2.0)
	draw_line(c + Vector2(-6.0, 86.0), c + Vector2(6.0, 86.0), line, 2.0)
	draw_dashed_line(c + Vector2(-72.0, -r), c + Vector2(-72.0, 86.0), thin, 1.0, 6.0)
	for y in [-r, 86.0]:
		draw_line(c + Vector2(-78.0, y), c + Vector2(-66.0, y), thin, 1.0)
