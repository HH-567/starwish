class_name EndingWorld
extends Node2D
## 正常结局动画的"世界"那一层（scripts/ui/ending_normal.gd 管时间线和小星）：天空、城市、噬光者、被吸走的光。
## 坐标是半分辨率画布的像素（镜头在画布正中、不缩放），全部用实心矩形/单像素画，配合 Nearest 放大成像素风。
## 所有东西都只看 time（秒）：同一个 time 永远画出同一帧，循环段因此首尾无缝。
##
## TODO(美术)：城市剪影没有现成素材，先用标题页 _draw_city 的色板和画法程序生成（同一套深蓝楼体 + 暖色窗）。
##   有了侧视角的城市像素图之后，替换 _draw_city()，每栋楼的变暗/熄灯时间表（_out_time）可以照用。

const SKY_TOP := Color("070b18")
const SKY_LOW := Color("0d1428")
const HAZE := Color(1.0, 0.78, 0.45)
const BUILDING := Color(0.065, 0.075, 0.13)
const BUILDING_FAR := Color(0.05, 0.058, 0.10)
const BUILDING_DEAD := Color(0.035, 0.038, 0.062)
const WINDOW := Color(1.0, 0.86, 0.6)
const BEACON := Color(1.0, 0.3, 0.35)
const GROUND := Color(0.045, 0.05, 0.09)
## 噬光者：游戏里的 devourer.png（88×81），眼睛颜色、描边颜色沿用 boss.gd。
const ART_BOSS := "res://assets/art/boss/devourer.png"
const BOSS_W := 88.0
const BOSS_H := 81.0
## devourer.png 里两只眼睛的像素位置（左上角为原点）。
const BOSS_EYES := [Vector2(18.5, 55.0), Vector2(36.0, 55.0)]
const EYE := Color("ff5a7a")
const RIM := Color("5a2a7a")
## 噬光者从哪一刻开始长、长到最大、开始缩、完全消失。
const GROW_FROM := 4.0
const GROW_TO := 7.2
const SHRINK_FROM := 7.6
const GONE := 8.4
const OMEN_FROM := 1.6
## 第一栋、最后一栋楼熄灭的时刻（由近到远）。
const OUT_FIRST := 4.5
const OUT_LAST := 7.1
const FLICKER := 0.4
const SUCK_TIME := 0.75
const SHOCK_AT := 7.4
const STARS := 70

var ending: EndingNormal
var time := 0.0

var _buildings: Array[Dictionary] = []
var _stars: Array[Vector3] = []
var _built_for := Vector2.ZERO
var _boss: Sprite2D
var _halo: Array[Sprite2D] = []
## 画在噬光者上面的一层：被吸走的光点、它身上的眼睛、冲击波、消散的碎屑。
var _front: Node2D

func _ready() -> void:
	var tex := load(ART_BOSS) as Texture2D
	# 剪影扩张：身后两层同一张图、压成近黑、放大一点，像一圈往外渗的暗。
	for k in 2:
		var h := Sprite2D.new()
		h.texture = tex
		h.offset = Vector2(0.0, -BOSS_H * 0.5)
		h.modulate = Color(0.02, 0.0, 0.05, 0.55 - 0.25 * k)
		add_child(h)
		_halo.append(h)
	_boss = Sprite2D.new()
	_boss.texture = tex
	# 锚点在底部正中：长大时脚底不动，往上、往两边长。
	_boss.offset = Vector2(0.0, -BOSS_H * 0.5)
	add_child(_boss)
	_front = Node2D.new()
	_front.draw.connect(_draw_front)
	add_child(_front)

func _canvas() -> Vector2:
	return ending.canvas_size() if ending != null else Vector2(640, 360)

func ground_y() -> float:
	return floorf(_canvas().y * 0.86)

## 小星出场的地方：城市中心偏下。
func spawn_point() -> Vector2:
	var s := _canvas()
	return Vector2(floorf(s.x * 0.5), floorf(s.y * 0.66))

func boss_anchor() -> Vector2:
	var s := _canvas()
	return Vector2(floorf(s.x * 0.5), s.y + 6.0)

## 噬光者最大时的缩放：高度占画面 72%。
func boss_full_scale() -> float:
	return _canvas().y * 0.72 / BOSS_H

## 噬光者的大小（0..1）：长大、缩回都用 easeInOut。
static func boss_size(t: float) -> float:
	if t < GROW_FROM or t >= GONE:
		return 0.0
	if t < GROW_TO:
		return _ease_in_out((t - GROW_FROM) / (GROW_TO - GROW_FROM))
	if t < SHRINK_FROM:
		return 1.0
	return 1.0 - _ease_in_out((t - SHRINK_FROM) / (GONE - SHRINK_FROM))

static func _ease_in_out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## 噬光者"嘴"（被吸的光飞向哪里）：身体中间偏下。
func boss_mouth() -> Vector2:
	var s := boss_size(time) * boss_full_scale()
	return boss_anchor() + Vector2(0.0, -BOSS_H * 0.45 * maxf(s, 0.6))

## 镜头震动（像素）：起飞时轻震，吞城时越来越重，冲击波那一下最重，8 秒后归零。
func shake(t: float) -> Vector2:
	var amp := 0.0
	if t > 1.2 and t < 3.0:
		amp = 1.2 * sin(PI * (t - 1.2) / 1.8)
	elif t > GROW_FROM and t < 8.0:
		amp = 1.0 + 1.6 * smoothstep(GROW_FROM, GROW_TO, t)
		amp += 4.0 * maxf(0.0, 1.0 - absf(t - SHOCK_AT) / 0.4)
		amp *= 1.0 - smoothstep(7.7, 8.0, t)
	if amp <= 0.01:
		return Vector2.ZERO
	var n := Vector2(sin(t * 53.1) + sin(t * 31.7 + 1.3), cos(t * 47.3) + sin(t * 23.9 + 0.7)) * 0.5
	return (n * amp).round()

func _build() -> void:
	var s := _canvas()
	if s == _built_for:
		return
	_built_for = s
	_buildings.clear()
	var g := ground_y()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261110
	# 远处一排矮的、暗的；近处一排高低错落的。和标题页的城市同一种楼：楼体 + 稀疏暖窗 + 楼顶红灯。
	for layer in 2:
		var x := -rng.randf_range(0.0, 20.0)
		while x < s.x:
			var w := floorf(rng.randf_range(20.0, 42.0) if layer == 1 else rng.randf_range(18.0, 34.0))
			var tall := rng.randf() < 0.3
			var h := floorf((rng.randf_range(0.34, 0.55) if tall else rng.randf_range(0.12, 0.30)) * s.y if layer == 1 else rng.randf_range(0.28, 0.60) * s.y)
			var rect := Rect2(floorf(x), g - h, w, h)
			var windows: Array[Vector2] = []
			for wx in range(4, int(w) - 3, 6):
				for wy in range(5, int(h) - 4, 8):
					if rng.randf() < (0.55 if layer == 1 else 0.35):
						windows.append(rect.position + Vector2(wx, wy))
			_buildings.append({"rect": rect, "far": layer == 0, "windows": windows,
				"beacon": rng.randf() < 0.45, "seed": rng.randf() * 100.0})
			x += w + (rng.randf_range(4.0, 16.0) if layer == 1 else rng.randf_range(-4.0, 6.0))
	# 熄灯顺序：离噬光者（底部正中）越近越早。
	var anchor := boss_anchor()
	var order := range(_buildings.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return _buildings[a]["rect"].get_center().distance_to(anchor) < _buildings[b]["rect"].get_center().distance_to(anchor))
	for rank in order.size():
		var k := float(rank) / maxf(order.size() - 1, 1)
		_buildings[order[rank]]["out"] = lerpf(OUT_FIRST, OUT_LAST, k)
	_stars.clear()
	for i in STARS:
		_stars.append(Vector3(rng.randf() * s.x, rng.randf() * g * 0.8, rng.randf() * TAU))

## 噬光者的精灵跟着 time 摆好：大小、色板呼吸、身后的暗影。
func sync_boss() -> void:
	_build()
	var size := boss_size(time)
	var full := boss_full_scale()
	var on := size > 0.001
	_boss.visible = on
	for h in _halo:
		h.visible = on
	if not on:
		return
	var sc := size * full
	_boss.position = boss_anchor()
	_boss.scale = Vector2.ONE * sc
	# 色板呼吸：在原色和偏紫红之间来回，1.2 秒一次
	var b := 0.5 + 0.5 * sin(time * TAU / 1.2)
	_boss.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.25, 0.85, 1.35), b)
	for k in _halo.size():
		_halo[k].position = boss_anchor()
		_halo[k].scale = Vector2.ONE * sc * (1.08 + 0.1 * k + 0.03 * b)

func _draw() -> void:
	_build()
	var s := _canvas()
	var g := ground_y()
	var t := time
	var lit := _lit_fraction(t)
	# 天空：上深下浅，城里亮着灯时地平线上有一层暖雾，灯灭一盏雾薄一分。
	var bands := 12
	for i in bands:
		var y0 := floorf(g * i / bands)
		var y1 := floorf(g * (i + 1) / bands)
		var k := float(i) / (bands - 1)
		var c := SKY_TOP.lerp(SKY_LOW, k)
		c = c.lerp(HAZE, 0.10 * k * k * lit)
		draw_rect(Rect2(0.0, y0, s.x, y1 - y0), c)
	# 星空：每颗按自己的相位闪，频率是循环段的整数倍，循环时接得上
	var ph := EndingNormal.phase(t)
	for st in _stars:
		var a := 0.25 + 0.2 * sin(TAU * ph + st.z)
		draw_rect(Rect2(Vector2(st.x, st.y).floor(), Vector2.ONE), Color(1, 1, 1, a))
	for bld in _buildings:
		_draw_building(bld, t)
	# 噬光者预兆：楼群里亮起一对红眼，慢慢睁开、眨一下；长出来以后由身体自己的眼睛接手
	_draw_omen(t)
	draw_rect(Rect2(0.0, g, s.x, s.y - g), GROUND)
	for x in range(0, int(s.x), 34):
		draw_rect(Rect2(x, g + 3.0, 30.0, 1.0), Color(0.07, 0.065, 0.10))
	_front.queue_redraw()

func _draw_front() -> void:
	var t := time
	_draw_suck(t)
	_draw_boss_eyes(t)
	_draw_shock(t)
	_draw_dissolve(t)

## 还亮着的楼的比例（暖雾、远处的光晕用）。
func _lit_fraction(t: float) -> float:
	if _buildings.is_empty():
		return 0.0
	var n := 0
	for bld in _buildings:
		if t < float(bld["out"]):
			n += 1
	return float(n) / _buildings.size()

## 一栋楼：灭灯前 FLICKER 秒灯开始乱闪，灭了之后楼体 0.3 秒内暗下去。
func _draw_building(bld: Dictionary, t: float) -> void:
	var rect: Rect2 = bld["rect"]
	var out: float = bld["out"]
	var dead := smoothstep(out, out + 0.3, t)
	var base := BUILDING_FAR if bld["far"] else BUILDING
	draw_rect(rect, base.lerp(BUILDING_DEAD, dead))
	# 楼顶一道细边（天空的余光）：灯全灭了也认得出这是一座城
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), Color(0.11, 0.12, 0.2, 0.9))
	# 楼顶天线和红灯
	if bld["beacon"]:
		var top := Vector2(floorf(rect.get_center().x), rect.position.y)
		draw_rect(Rect2(top + Vector2(0, -6), Vector2(1, 6)), base.lerp(BUILDING_DEAD, dead))
		if t < out and fmod(t + float(bld["seed"]), 1.4) < 0.9:
			draw_rect(Rect2(top + Vector2(-1, -8), Vector2(2, 2)), Color(BEACON, 0.75 if not bld["far"] else 0.45))
	if t >= out:
		return
	var flicker := t > out - FLICKER
	var dim := 0.55 if bld["far"] else 1.0
	var i := 0
	for w: Vector2 in bld["windows"]:
		i += 1
		var on := true
		if flicker:
			# 闪：每扇窗按自己的节奏一会儿亮一会儿灭，越接近熄灭灭得越多
			var k := (t - (out - FLICKER)) / FLICKER
			on = fposmod(sin(i * 12.9898 + floorf(t * 16.0) * 4.1) * 43758.5453, 1.0) > k * 0.85
		if on:
			var warm := 0.55 + 0.25 * float(i % 3) / 2.0
			draw_rect(Rect2(w, Vector2(2, 3)), Color(WINDOW, warm * dim))

## 熄灭的窗：光点沿弧线被吸向噬光者的嘴，越近越快、越小。
func _draw_suck(t: float) -> void:
	if t < OUT_FIRST - 0.1 or t > OUT_LAST + 0.2 + SUCK_TIME:
		return
	var mouth := boss_mouth()
	for bld in _buildings:
		var out: float = bld["out"]
		if t < out or t > out + SUCK_TIME + 0.15:
			continue
		var i := 0
		for w: Vector2 in bld["windows"]:
			i += 1
			if i % 2 == 0 and bld["far"]:
				continue
			var delay := fposmod(i * 0.137, 0.15)
			var k := (t - out - delay) / SUCK_TIME
			if k <= 0.0 or k >= 1.0:
				continue
			var e := k * k * k
			var from := w + Vector2(1, 1)
			var swirl := (from - mouth).orthogonal().normalized() * 18.0 * sin(PI * k)
			var p := from.lerp(mouth, e) + swirl
			var c := Color(WINDOW, 1.0 - 0.6 * k)
			_front.draw_rect(Rect2(p.floor(), Vector2.ONE * (2.0 if k < 0.5 else 1.0)), c)

## 预兆：1.6 秒起，在噬光者最终的眼睛位置亮起一对红眼。
func _draw_omen(t: float) -> void:
	if t < OMEN_FROM or t > GROW_FROM + 1.2:
		return
	var a := smoothstep(OMEN_FROM, OMEN_FROM + 0.8, t) * (1.0 - smoothstep(GROW_FROM + 0.4, GROW_FROM + 1.2, t))
	# 2.7 秒眨一下
	if absf(t - 2.7) < 0.08:
		a *= 0.15
	var full := boss_full_scale()
	for e: Vector2 in BOSS_EYES:
		var p := (boss_anchor() + (e - Vector2(BOSS_W * 0.5, BOSS_H)) * full).floor()
		draw_rect(Rect2(p - Vector2(5, 4), Vector2(11, 9)), Color(EYE, 0.10 * a))
		draw_rect(Rect2(p - Vector2(3, 2), Vector2(7, 5)), Color(EYE, 0.22 * a))
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Color(EYE, 0.95 * a))

## 长出来的噬光者：身上那对眼睛用 boss.gd 的红色自己发光（和游戏里一样压在贴图上面）。
func _draw_boss_eyes(t: float) -> void:
	var size := boss_size(t)
	if size <= 0.05:
		return
	var sc := size * boss_full_scale()
	var blink := 0.2 if fmod(t, 2.3) < 0.1 else 1.0
	for e: Vector2 in BOSS_EYES:
		var p := (boss_anchor() + (e - Vector2(BOSS_W * 0.5, BOSS_H)) * sc).floor()
		var r := maxf(floorf(1.5 * sc), 1.0)
		_front.draw_rect(Rect2(p - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), Color(EYE, 0.12 * blink * size))
		_front.draw_rect(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), Color(EYE, 0.95 * blink))

## 高潮：冲击波从噬光者身上往外推，一圈像素环。
func _draw_shock(t: float) -> void:
	var k := (t - SHOCK_AT) / 0.55
	if k < 0.0 or k > 1.0:
		return
	var r := _canvas().x * 0.9 * (1.0 - pow(1.0 - k, 2.0))
	var c := boss_mouth()
	_front.draw_arc(c, r, 0.0, TAU, 96, Color(0.85, 0.7, 1.0, 0.8 * (1.0 - k)), 2.0, false)
	_front.draw_arc(c, r * 0.82, 0.0, TAU, 96, Color(RIM, 0.6 * (1.0 - k)), 3.0, false)

## 缩回去的时候：身上散出暗紫的碎屑往上飘，8.4 秒前全部散完。
func _draw_dissolve(t: float) -> void:
	if t < SHRINK_FROM or t >= GONE:
		return
	var k := (t - SHRINK_FROM) / (GONE - SHRINK_FROM)
	var sc := boss_full_scale()
	for i in 40:
		var seed := float(i) * 2.399963
		var start := Vector2(sin(seed) * BOSS_W * 0.45, -BOSS_H * (0.2 + 0.6 * fposmod(seed, 1.0))) * sc * (1.0 - 0.5 * k)
		var p := boss_anchor() + start + Vector2(sin(seed * 3.0) * 20.0, -60.0) * k
		var c := RIM.lerp(Color(0.02, 0.0, 0.05), fposmod(seed * 7.0, 1.0))
		_front.draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(c, 1.0 - k))
