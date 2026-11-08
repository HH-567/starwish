@tool
class_name HitBurst
extends Node2D
## 打碎敌人时的"打击感"：一圈白热冲击环 + 中心闪光 + 几道放射火花。
## 和 Shatter（死亡碎片）不同，这个只有 0.3 秒，用来强调"这一下打中了"。

const LIFE := 0.3
const RING_MAX := 44.0
const SHARDS := 7

var color := Color("ffe9a0")
var _t := 0.0
var _rays: Array[float] = []

static func spawn(parent: Node, pos: Vector2, tint := Color("ffe9a0"), scale_mul := 1.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var fx := HitBurst.new()
	fx.color = tint
	fx.scale = Vector2.ONE * scale_mul
	fx.material = Lighting.unshaded()
	fx.global_position = pos
	for i in SHARDS:
		fx._rays.append(randf() * TAU)
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
	# 冲击环：前 40% 冲出去，后面淡掉
	var r := lerpf(6.0, RING_MAX, smoothstep(0.0, 0.4, k))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color, 0.95 * fade), lerpf(4.0, 1.0, k), true)
	# 中心闪光
	if k < 0.45:
		draw_circle(Vector2.ZERO, lerpf(9.0, 2.0, k / 0.45), Color(1.0, 1.0, 1.0, 0.9 * (1.0 - k / 0.45)))
	# 放射火花
	for angle in _rays:
		var dir := Vector2.from_angle(angle)
		var inner := r * 0.55
		var outer := r * 1.15
		draw_line(dir * inner, dir * outer, Color(color, 0.8 * fade), lerpf(2.5, 0.5, k), true)
