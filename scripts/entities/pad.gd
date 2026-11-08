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
	Shapes.add_occluder(self, size)
	var frame := Node2D.new()
	frame.material = Lighting.unshaded()
	frame.draw.connect(func() -> void: frame.draw_rect(Rect2(-size * 0.5, size).grow(-4.0), Color(COLOR.lightened(0.3), 0.6), false, 2.0))
	add_child(frame)

func smash() -> void:
	collision_layer = 0
	Debris.spawn(get_parent(), global_position, COLOR.lightened(0.3), 12, 260.0, 7.0)
	queue_free()

func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	# 外框 + 内芯：长条软垫就沿长边铺一格一格的软包。
	draw_rect(rect, COLOR)
	draw_rect(rect, HILIGHT, false, 2.0)
	var along_x := size.x >= size.y
	var length := size.x if along_x else size.y
	var cells := maxi(int(round(length / 32.0)), 1)
	for i in cells:
		var t0 := -length * 0.5 + length * i / cells
		var t1 := t0 + length / cells
		var t := Vector2(t0, t1) if along_x else Vector2(t0, t1)
		var cell: Rect2
		if along_x:
			cell = Rect2(t.x + 3.0, -size.y * 0.5 + 3.0, (t.y - t.x) - 6.0, size.y - 6.0)
		else:
			cell = Rect2(-size.x * 0.5 + 3.0, t.x + 3.0, size.x - 6.0, (t.y - t.x) - 6.0)
		draw_rect(cell, INNER)
		# 中间一道亮缝，像缝线。
		if along_x:
			draw_line(Vector2(cell.position.x + 2.0, 0.0), Vector2(cell.end.x - 2.0, 0.0), Color(HILIGHT, 0.35), 1.0)
		else:
			draw_line(Vector2(0.0, cell.position.y + 2.0), Vector2(0.0, cell.end.y - 2.0), Color(HILIGHT, 0.35), 1.0)
