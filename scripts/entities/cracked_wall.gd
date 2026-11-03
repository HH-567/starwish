@tool
class_name CrackedWall
extends StaticBody2D
## 裂纹墙：阶段 4 以上撞碎（docs/state-machines.md 第 5 节）。撞碎后记进存档，重载不再出现。
## 裂缝自己微微发光，暗处也认得出。

const COLOR := Color("4a3d5c")

@export var size := Vector2(64.0, 64.0):
	set(value):
		size = value
		queue_redraw()

var save_id := ""

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	save_id = Save.id_of(self)
	if Save.broken.has(save_id):
		queue_free()
		return
	collision_layer = Layers.CRACKED
	collision_mask = 0
	Shapes.add_rect(self, size)
	Shapes.add_occluder(self, size)
	var cracks := Node2D.new()
	cracks.material = Lighting.unshaded()
	cracks.draw.connect(_draw_cracks.bind(cracks, Color(COLOR.lightened(0.55), 0.55)))
	add_child(cracks)

func smash() -> void:
	collision_layer = 0
	Save.broken[save_id] = true
	Debris.spawn(get_parent(), global_position, COLOR.lightened(0.3), 18, 320.0, 8.0)
	Game.wall_broken.emit(save_id)
	queue_free()

func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, COLOR)
	draw_rect(rect, COLOR.lightened(0.3), false, 2.0)
	if Engine.is_editor_hint():
		_draw_cracks(self, COLOR.lightened(0.55))

func _draw_cracks(item: CanvasItem, line: Color) -> void:
	var half := size * 0.5
	item.draw_polyline(PackedVector2Array([Vector2(-1.0, -0.3) * half, Vector2(-0.3, -0.1) * half, Vector2(0.0, 0.2) * half, Vector2(0.4, 0.05) * half, Vector2(1.0, 0.4) * half]), line, 2.0)
	item.draw_polyline(PackedVector2Array([Vector2(-0.3, -0.1) * half, Vector2(-0.1, -1.0) * half]), line, 2.0)
	item.draw_polyline(PackedVector2Array([Vector2(0.0, 0.2) * half, Vector2(-0.2, 1.0) * half]), line, 2.0)
