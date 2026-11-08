@tool
class_name HelpFx
extends Node2D
## 小人挡下噬光者时的特效：一圈从脚下炸开的光环 + 一道打向噬光者的光柱 + 碎光。
## 配合镜头特写用（docs/state-machines.md 第 18 节）。

const LIFE := 1.1
const RING_MAX := 96.0

var color := Color("ffe9b0")
var target := Vector2.ZERO
var _t := 0.0

static func spawn(parent: Node, from: Vector2, to: Vector2, tint := Color("ffe9b0")) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var fx := HelpFx.new()
	fx.color = tint
	fx.target = to
	fx.material = Lighting.unshaded()
	fx.global_position = from
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
	# 脚下炸开的光环
	var r := lerpf(8.0, RING_MAX, smoothstep(0.0, 0.45, k))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(color, 0.85 * fade), 3.0, true)
	draw_arc(Vector2.ZERO, r * 0.65, 0.0, TAU, 40, Color(color, 0.5 * fade), 2.0, true)
	# 打向噬光者的光柱（起点画在本地坐标里）
	var dir := target - global_position
	if dir.length() > 4.0:
		var to_local := dir
		var width := lerpf(10.0, 1.0, smoothstep(0.0, 0.6, k))
		draw_line(Vector2.ZERO, to_local, Color(color, 0.75 * fade), width)
		draw_line(Vector2.ZERO, to_local, Color(1.0, 1.0, 1.0, 0.5 * fade), width * 0.35)
	# 中心的一团亮
	if k < 0.5:
		draw_circle(Vector2.ZERO, lerpf(6.0, 26.0, k / 0.5), Color(color, 0.55 * (1.0 - k / 0.5)))
