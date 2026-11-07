@tool
class_name Mirror
extends StaticBody2D
## 玻璃：挡路也挡光；聚光的中心射线打到它时反射一次（docs/state-machines.md 2.4）。
## 沿本地 X 轴摆放，长 length，旋转节点来改角度。玻璃边自己微微发光，暗处也认得出。

const COLOR := Color("9fd8ff")
const THICKNESS := 8.0
## 美术图：横版的 64×16 镜子（已经是横的），按 length × 厚度铺开。
const ART := "res://assets/art/items/mirror_h.png"

var _tex: Texture2D

@export var length := 96.0:
	set(value):
		length = value
		queue_redraw()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = Layers.MIRROR
	collision_mask = 0
	var size := Vector2(length, THICKNESS)
	Shapes.add_rect(self, size)
	Shapes.add_occluder(self, size)
	if ResourceLoader.exists(ART):
		_tex = load(ART) as Texture2D
	var edge := Node2D.new()
	edge.material = Lighting.unshaded()
	edge.draw.connect(func() -> void: edge.draw_line(Vector2(-length * 0.5, 0.0), Vector2(length * 0.5, 0.0), Color(COLOR, 0.45), 2.0, true))
	add_child(edge)

## 阶段 5 撞上会碎。
func smash() -> void:
	collision_layer = 0
	Debris.spawn(get_parent(), global_position, COLOR, 14, 280.0, 6.0, true)
	queue_free()

func _draw() -> void:
	if _tex != null and not Engine.is_editor_hint():
		# 贴图拉成 length × 厚度，正好填满碰撞盒。
		draw_texture_rect(_tex, Rect2(Vector2(-length, -THICKNESS) * 0.5, Vector2(length, THICKNESS)), false)
		return
	var half := Vector2(length, THICKNESS) * 0.5
	draw_rect(Rect2(-half, half * 2.0), Color(COLOR, 0.3))
	if Engine.is_editor_hint():
		draw_line(Vector2(-half.x, 0.0), Vector2(half.x, 0.0), COLOR, 2.0)
