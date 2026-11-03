class_name Debris
extends Node2D
## 一次性碎片特效：三角碎片向外飞散、旋转、淡出，播完自己删除。

const LIFE := 0.8

var color := Color.WHITE
var _parts: Array = []
var _t := 0.0

## glow 为真时碎片自己发光，暗处也看得见。
static func spawn(parent: Node, pos: Vector2, tint: Color, count := 14, speed := 260.0, size := 7.0, glow := false) -> void:
	var fx := Debris.new()
	fx.color = tint
	if glow:
		fx.material = Lighting.unshaded()
	for i in count:
		var vel := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.35, 1.0)
		fx._parts.append([Vector2.ZERO, vel, randf() * TAU, randf_range(-9.0, 9.0), size * randf_range(0.6, 1.3)])
	parent.add_child(fx)
	fx.global_position = pos

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	var drag := pow(0.05, delta)
	for p in _parts:
		p[0] += p[1] * delta
		p[1] *= drag
		p[2] += p[3] * delta
	queue_redraw()

func _draw() -> void:
	var c := Color(color, 1.0 - _t / LIFE)
	for p in _parts:
		var pts := PackedVector2Array()
		for k in 3:
			pts.append(p[0] + Vector2.from_angle(p[2] + TAU * k / 3.0) * p[4])
		draw_colored_polygon(pts, c)
