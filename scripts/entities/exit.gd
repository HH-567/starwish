@tool
class_name Exit
extends Area2D
## 出口：一直开着，小星进入时发 chapter_cleared（docs/state-machines.md 第 7 节）。
## 没有必救的人，没救的人就留在这一章里。
## 出口是一章的目标，要像一盏灯塔：拱门 + 门里的光 + 往上飘的光点，再带一盏会被墙挡住的暖光，
## 远远就能看见那个方向亮着。原来的 exit.png 是一个平的方框，暗处不起眼，改成程序画。

enum State { OPEN, CLEARED }

const COLOR := Color("ffd75a")
const MOTES := 10
const LIGHT_RADIUS := 170.0

@export var size := Vector2(64.0, 64.0):
	set(value):
		size = value
		queue_redraw()

var state := State.OPEN
var _t := 0.0
var _lamp: PointLight2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	material = Lighting.unshaded()
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	Shapes.add_rect(self, size)
	body_entered.connect(_on_body_entered)
	_lamp = Lighting.point_light(LIGHT_RADIUS, COLOR, 0.85, true)
	add_child(_lamp)

func _process(delta: float) -> void:
	_t += delta
	if _lamp != null:
		# 门里的光呼吸一下，暗处也能注意到。
		_lamp.energy = 0.75 + 0.15 * sin(_t * 3.0)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not body is Player or state != State.OPEN:
		return
	state = State.CLEARED
	Debris.spawn(get_parent(), global_position, COLOR, 24, 260.0, 5.0, true)
	HitBurst.spawn(get_parent(), global_position, COLOR, 1.6)
	var chapter := Save.chapter_of(self)
	Game.chapter_cleared.emit(chapter.get("chapter_id") if chapter != null else &"")

func _draw() -> void:
	var half := size * 0.5
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	# 地上一圈柔光
	for k in 4:
		draw_circle(Vector2.ZERO, half.x * (1.6 - 0.3 * k), Color(COLOR, 0.04 + 0.02 * pulse))
	# 拱门：两根门柱 + 半圆门顶，门里由下往上渐亮
	var w := half.x * 0.62
	var top := -half.y * 0.35
	var bottom := half.y * 0.85
	var arch := PackedVector2Array()
	for i in 13:
		arch.append(Vector2(0.0, top) + Vector2.from_angle(PI + PI * i / 12.0) * w)
	var inner := arch.duplicate()
	inner.append(Vector2(w, bottom))
	inner.append(Vector2(-w, bottom))
	draw_colored_polygon(inner, Color(1.0, 0.92, 0.65, 0.5 + 0.2 * pulse))
	var core := PackedVector2Array()
	for p in inner:
		core.append(Vector2(p.x * 0.55, lerpf(bottom, p.y, 0.8)))
	draw_colored_polygon(core, Color(1.0, 1.0, 0.92, 0.6 + 0.3 * pulse))
	var frame := PackedVector2Array([Vector2(-w - 3.0, bottom)])
	for i in 13:
		frame.append(Vector2(0.0, top) + Vector2.from_angle(PI + PI * i / 12.0) * (w + 3.0))
	frame.append(Vector2(w + 3.0, bottom))
	draw_polyline(frame, COLOR, 3.0, true)
	draw_line(Vector2(-w - 8.0, bottom + 1.5), Vector2(w + 8.0, bottom + 1.5), COLOR, 3.0, true)
	# 往上飘的光点：从门里升起来、飘出门顶淡掉
	for i in MOTES:
		var k := fposmod(_t * 0.35 + float(i) / MOTES, 1.0)
		var x := sin(i * 12.9898 + _t * 1.3) * w * 0.7
		var y := lerpf(bottom, top - w - 18.0, k)
		draw_circle(Vector2(x, y), 1.6, Color(1.0, 0.95, 0.7, 0.9 * (1.0 - k) * minf(k * 5.0, 1.0)))
