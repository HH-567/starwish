class_name Shatter
extends Node2D
## 小星熄灭/碎裂的特效（docs/state-machines.md 第 2 节死亡那段）：
## 一道白光炸开、一圈冲击环扩散，星体碎成三十来块三角碎片向外飞散、旋转、淡出。
## 和 Debris 的区别：更大、更慢、带闪光和冲击环，专门给"死亡"用。

const LIFE := 1.1
## 闪光和冲击环持续多久。
const FLASH_TIME := 0.3
const SHARDS := 30

var color := Color.WHITE
var _parts: Array = []
var _t := 0.0

static func spawn(parent: Node, pos: Vector2, tint: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var fx := Shatter.new()
	fx.color = tint
	fx.material = Lighting.unshaded()
	for i in SHARDS:
		var angle := randf() * TAU
		# 先快后慢：高速碎片少、低速碎片多，看起来像被炸开
		var speed := randf_range(380.0, 720.0) * randf_range(0.7, 1.0)
		var vel := Vector2.from_angle(angle) * speed
		fx._parts.append([Vector2.ZERO, vel, randf() * TAU, randf_range(-10.0, 10.0), randf_range(4.0, 11.0)])
	parent.add_child(fx)
	fx.global_position = pos

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	var drag := pow(0.08, delta)
	for p in _parts:
		p[0] += p[1] * delta
		p[1] *= drag
		p[2] += p[3] * delta
	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / LIFE, 0.0, 1.0)
	var fade := 1.0 - k
	# 闪光：不铺一大块实心，而是"亮核 + 一圈冲击波"，暗背景上才不糊成一坨
	if _t < FLASH_TIME:
		var f := 1.0 - _t / FLASH_TIME
		draw_circle(Vector2.ZERO, 16.0 + 34.0 * (1.0 - f), Color(1, 1, 1, 0.85 * f * f))
		draw_circle(Vector2.ZERO, 34.0 + 60.0 * (1.0 - f), Color(color.lightened(0.4), 0.55 * f * f))
		draw_arc(Vector2.ZERO, 30.0 + 300.0 * k, 0.0, TAU, 56, Color(color.lightened(0.5), 0.8 * f), 6.0 * f + 1.0, true)
	# 冲击环：向外扩、越扩越淡
	var ring := 46.0 + 240.0 * k
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 56, Color(color, 0.55 * fade * fade), 1.0 + 3.0 * fade, true)
	# 碎片：亮金色的三角，边缘带一点白
	var c := Color(color.lightened(0.25), fade)
	for p in _parts:
		var pts := PackedVector2Array()
		for i in 3:
			pts.append(p[0] + Vector2.from_angle(p[2] + TAU * i / 3.0) * p[4])
		draw_colored_polygon(pts, c)
		pts.append(pts[0])
		draw_polyline(pts, Color(1, 1, 1, 0.35 * fade), 1.0, true)
