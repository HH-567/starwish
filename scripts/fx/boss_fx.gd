@tool
class_name BossFx
extends Node2D
## 噬光者的技能特效：登场、冲刺残影、被击退、被减速，各有一套看得懂的图形。
## 和 HitBurst（打碎敌人）区分：这里都是大尺度、慢一点、带紫边。

enum Kind { EMERGE, DASH, KNOCK, SLOW }

const LIFE_EMERGE := 1.2
const LIFE_DASH := 0.35
const LIFE_RING := 0.8

var kind := Kind.EMERGE
var color := Color("5a2a7a")
var radius := 56.0
var target := Vector2.ZERO
var _t := 0.0

static func emerge(parent: Node, pos: Vector2, r: float) -> void:
	_spawn(parent, pos, Kind.EMERGE, Color("5a2a7a"), r, Vector2.ZERO)

static func dash(parent: Node, from: Vector2, to: Vector2) -> void:
	_spawn(parent, from, Kind.DASH, Color("05030a"), 40.0, to - from)

static func knock(parent: Node, pos: Vector2, to: Vector2) -> void:
	_spawn(parent, pos, Kind.KNOCK, Color("ffb454"), 70.0, to - pos)

static func slow(parent: Node, pos: Vector2) -> void:
	_spawn(parent, pos, Kind.SLOW, Color("9fd8ff"), 80.0, Vector2.ZERO)

static func _spawn(parent: Node, pos: Vector2, k: Kind, tint: Color, r: float, dir: Vector2) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var fx := BossFx.new()
	fx.kind = k
	fx.color = tint
	fx.radius = r
	fx.target = dir
	fx.material = Lighting.unshaded()
	fx.global_position = pos
	parent.add_child(fx)

func _process(delta: float) -> void:
	_t += delta
	if _t >= _life():
		queue_free()
		return
	queue_redraw()

func _life() -> float:
	match kind:
		Kind.EMERGE:
			return LIFE_EMERGE
		Kind.DASH:
			return LIFE_DASH
		_:
			return LIFE_RING

func _draw() -> void:
	var life := _life()
	var k := clampf(_t / life, 0.0, 1.0)
	var fade := 1.0 - k
	match kind:
		Kind.EMERGE:
			# 登场：两圈紫环往外推 + 中心压暗，像从地里浮上来
			for i in 2:
				var rr := lerpf(radius * 0.4, radius * (2.2 + 0.5 * i), smoothstep(0.0, 0.75, k))
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 48, Color(color, 0.8 * fade * (1.0 - 0.3 * i)), 3.0, true)
			draw_circle(Vector2.ZERO, radius * (1.0 - 0.6 * k), Color(0.02, 0.01, 0.04, 0.55 * fade))
		Kind.DASH:
			# 冲刺残影：一条从起点到当前位置的渐隐带
			var len := target.length()
			if len > 2.0:
				var dir := target.normalized()
				var side := dir.orthogonal() * radius * 0.45 * fade
				draw_line(-target, Vector2.ZERO, Color(color, 0.6 * fade), radius * 0.8 * fade)
				draw_line(-target + side, Vector2.ZERO + side, Color(0.35, 0.15, 0.5, 0.5 * fade), 3.0)
		Kind.KNOCK:
			# 被乐手击退：一圈暖金冲击环 + 朝反方向的一道推力线
			var rr := lerpf(radius * 0.5, radius * 1.6, smoothstep(0.0, 0.6, k))
			draw_arc(Vector2.ZERO, rr, 0.0, TAU, 40, Color(color, 0.9 * fade), 4.0 * fade + 1.0, true)
			if target.length() > 2.0:
				draw_line(Vector2.ZERO, -target.normalized() * radius * 1.2, Color(color, 0.7 * fade), 5.0 * fade)
		Kind.SLOW:
			# 被钟表匠减速：三圈蓝色时间涟漪，慢速往里收
			for i in 3:
				var rr := radius * (1.4 - 0.3 * i) * (1.0 - 0.5 * k)
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 36, Color(color, (0.55 - 0.15 * i) * fade), 2.0, true)
