@tool
class_name Pad
extends StaticBody2D
## 软垫：阶段 1–4 撞上急停、不受伤；阶段 5 撞碎（docs/state-machines.md 2.3）。
## 内框自己微微发光，暗处也认得出。

const COLOR := Color("2f8f83")
## 软垫自己画：一块磨圆的青绿软包，中间深、边上亮，撞上去像按进棉花里。
const INNER := Color("1d5f57")
const HILIGHT := Color("7fe0c8")

@export var size := Vector2(32.0, 128.0):
	set(value):
		size = value
		queue_redraw()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = Layers.PAD
	collision_mask = 0
	Shapes.add_rect(self, size)
	# 遮光体比垫子小一圈：和墙一样，光能照亮垫子的边，不然整块垫子落在自己的影子里是黑的。
	Shapes.add_occluder(self, (size - Vector2(12.0, 12.0)).max(Vector2(4.0, 4.0)))
	var frame := Node2D.new()
	frame.material = Lighting.unshaded()
	frame.draw.connect(func() -> void: frame.draw_rect(Rect2(-size * 0.5, size).grow(-3.0), Color(COLOR.lightened(0.3), 0.3), false, 1.5))
	add_child(frame)

func smash() -> void:
	collision_layer = 0
	Debris.spawn(get_parent(), global_position, COLOR.lightened(0.3), 12, 260.0, 7.0)
	queue_free()

func _draw() -> void:
	# 一长条软包：圆角的布面，每格中间一颗内陷的扣子，四周一道亮边——看起来是软的、能按进去，
	# 不像原来那种方框（暗处看着像界面按钮）。
	var rect := Rect2(-size * 0.5, size).grow(-2.0)
	_round_rect(rect, 6.0, COLOR.darkened(0.25))
	_round_rect(rect.grow(-2.0), 5.0, COLOR)
	_round_rect(Rect2(rect.position + Vector2(3.0, 3.0), Vector2(rect.size.x - 6.0, minf(5.0, rect.size.y * 0.25))), 2.5, Color(HILIGHT, 0.25))
	var along_x := size.x >= size.y
	var length := size.x if along_x else size.y
	var cells := maxi(int(round(length / 32.0)), 1)
	for i in cells:
		var t := -length * 0.5 + length * (i + 0.5) / cells
		var c := Vector2(t, 0.0) if along_x else Vector2(0.0, t)
		# 扣子：一圈浅色的褶 + 中间深色的凹点
		for k in 4:
			var d := Vector2.from_angle(PI * 0.25 + PI * 0.5 * k)
			draw_line(c + d * 3.0, c + d * 9.0, Color(INNER, 0.8), 1.5, true)
		draw_circle(c, 3.0, INNER.darkened(0.3))
		draw_circle(c + Vector2(-0.8, -0.8), 1.0, Color(HILIGHT, 0.5))

## 圆角矩形（实心）：四个角各一段圆弧拼成的多边形。
func _round_rect(r: Rect2, radius: float, c: Color) -> void:
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(r.size.x - radius, radius), r.end - Vector2(radius, radius),
			Vector2(r.position.x + radius, r.end.y - radius), r.position + Vector2(radius, radius)]
	for k in 4:
		for j in 5:
			pts.append(corners[k] + Vector2.from_angle(-PI * 0.5 + PI * 0.5 * k + PI * 0.5 * j / 4.0) * radius)
	draw_colored_polygon(pts, c)
