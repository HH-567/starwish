@tool
class_name Pad
extends StaticBody2D
## 软垫：阶段 1–4 撞上急停、不受伤；阶段 5 撞碎（docs/state-machines.md 2.3）。
## 内框自己微微发光，暗处也认得出。

const COLOR := Color("2f8f83")

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
	draw_rect(rect, COLOR)
	if Engine.is_editor_hint():
		draw_rect(rect.grow(-4.0), COLOR.lightened(0.3), false, 2.0)
