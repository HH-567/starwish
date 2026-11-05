class_name Dissolve
extends Node2D
## 小星"熄灭"（亮度随时间耗尽）的时候用的死亡演出：不炸、不碎，而是**化开**。
## 一簇光点从星体位置慢慢升起来、边升边散、边淡；再有一圈收缩的光环把它收走。
## 和 Shatter 的区别就是这份"慢慢没了"：撞墙碎裂是暴烈的，油尽灯枯是安静的。

const LIFE := 1.4
const MOTES := 34
const RISE := 90.0
## 光环从多大收到多小。
const RING_FROM := 46.0
const RING_TO := 4.0

var color := Color.WHITE
## [位置, 速度, 相位, 大小]
var _motes: Array = []
var _t := 0.0

static func spawn(parent: Node, pos: Vector2, tint: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var fx := Dissolve.new()
	fx.color = tint
	fx.material = Lighting.unshaded()
	for i in MOTES:
		var angle := randf() * TAU
		var radius := randf_range(2.0, 16.0)
		var offset := Vector2.from_angle(angle) * radius
		# 往上飘：水平速度很小、带一点左右摇摆
		var vel := Vector2(randf_range(-26.0, 26.0), -randf_range(28.0, 95.0))
		fx._motes.append([offset, vel, randf() * TAU, randf_range(1.2, 3.4)])
	parent.add_child(fx)
	fx.global_position = pos

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	for m in _motes:
		m[0] += m[1] * delta
		m[2] += delta * 2.5
	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / LIFE, 0.0, 1.0)
	var fade := 1.0 - k
	# 收缩的光环：像被收拢最后一口气
	var ring := lerpf(RING_FROM, RING_TO, k)
	draw_arc(Vector2.ZERO, ring, 0.0, TAU, 48, Color(color, 0.55 * fade), 1.0 + 2.0 * fade, true)
	# 光点：越往上越淡，最后散没
	for m in _motes:
		var p: Vector2 = m[0]
		var sway := sin(m[2]) * 2.0
		draw_circle(p + Vector2(sway, 0.0), m[3] * (0.6 + 0.4 * fade), Color(color.lightened(0.35), fade * 0.9))
