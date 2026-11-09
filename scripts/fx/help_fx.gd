@tool
class_name HelpFx
extends Node2D
## 小人挡下噬光者时的特效（配合镜头特写用）：
##   · 脚下炸开的双环
##   · 一道竖直的光柱（特写里最好认的形状）
##   · 中心白闪 + 放射短光
## 之前那道"打向噬光者的光柱"在特写里只剩一根黄线，已经去掉。

const LIFE := 1.2
const RING_MAX := 110.0
const BEAM_H := 260.0
const RAYS := 8

var color := Color("ffe9b0")
var _t := 0.0
var _ray_angles: Array[float] = []

static func spawn(parent: Node, from: Vector2, to: Vector2, tint := Color("ffe9b0"), scale_mul := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var fx := HelpFx.new()
	fx.color = tint
	fx.scale = Vector2.ONE * scale_mul
	fx.material = Lighting.unshaded()
	fx.global_position = from
	for i in RAYS:
		fx._ray_angles.append(TAU * float(i) / float(RAYS))
	parent.add_child(fx)

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / LIFE, 0.0, 1.0)
	var fade := 1.0 - k
	# 双环：一环快一环慢，都从脚下炸开
	for i in 2:
		var rk := clampf((k - 0.06 * i) / 0.45, 0.0, 1.0)
		var r := lerpf(10.0, RING_MAX * (1.0 - 0.25 * i), smoothstep(0.0, 1.0, rk))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(color, (0.95 - 0.35 * i) * (1.0 - rk)), lerpf(9.0, 2.0, rk), true)
	# 中心白闪
	if k < 0.4:
		var f := 1.0 - k / 0.4
		draw_circle(Vector2.ZERO, lerpf(34.0, 8.0, k / 0.4), Color(1.0, 1.0, 1.0, 0.9 * f))
	# 四角星芒（特写里最好认的"帮忙"符号）
	var star_r := lerpf(18.0, 96.0, smoothstep(0.0, 0.5, k))
	var star_a := fade * 0.95
	var pts := PackedVector2Array()
	for i in 8:
		var ang := TAU * float(i) / 8.0 - PI / 2.0
		var rr := star_r if i % 2 == 0 else star_r * 0.26
		pts.append(Vector2.from_angle(ang) * rr)
	draw_colored_polygon(pts, Color(1.0, 0.96, 0.85, star_a * 0.85))
	# 内层白星：让它读起来是"闪光"，不是一块灰
	var inner := PackedVector2Array()
	for i in 8:
		var ang2 := TAU * float(i) / 8.0 - PI / 2.0
		var rr2 := (star_r * 0.5) if i % 2 == 0 else (star_r * 0.14)
		inner.append(Vector2.from_angle(ang2) * rr2)
	draw_colored_polygon(inner, Color(1.0, 1.0, 1.0, star_a))
