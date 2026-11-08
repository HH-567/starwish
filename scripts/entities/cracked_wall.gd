@tool
class_name CrackedWall
extends StaticBody2D
## 裂纹墙：阶段 4 以上撞碎（docs/state-machines.md 第 5 节）。撞碎后记进存档，重载不再出现。
## 裂缝自己微微发光，暗处也认得出。

const COLOR := Color("4a3d5c")
## 美术图：64×64 的裂纹石砖（完好 / 裂开两张），按 size 拉伸。
const ART_INTACT := "res://assets/art/level/crack_wall.png"
const ART_BROKEN := "res://assets/art/level/crack_wall_broken.png"

var _art: Sprite2D
var _tex_intact: Texture2D
var _tex_broken: Texture2D
## 撞过一次但没碎的时候用裂开那张。
var cracked := false

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
	_load_art()

func _load_art() -> void:
	if ResourceLoader.exists(ART_INTACT):
		_tex_intact = load(ART_INTACT) as Texture2D
	if ResourceLoader.exists(ART_BROKEN):
		_tex_broken = load(ART_BROKEN) as Texture2D

func smash() -> void:
	collision_layer = 0
	Save.broken[save_id] = true
	Debris.spawn(get_parent(), global_position, COLOR.lightened(0.3), 18, 320.0, 8.0)
	Game.wall_broken.emit(save_id)
	queue_free()

func _draw() -> void:
	if _art != null:
		return
	var rect := Rect2(-size * 0.5, size)
	if _tex_intact != null:
		# 平铺而不是拉伸：1×3 格的墙就重复三块砖，不会被压扁成一条。
		draw_texture_rect(_tex_intact, rect, true)
		# 一圈暖色细边，和普通墙区分开——这是"撞得碎"的墙。
		draw_rect(rect, Color(0.95, 0.72, 0.4, 0.45), false, 1.0)
		return
	draw_rect(rect, COLOR)
	draw_rect(rect, COLOR.lightened(0.3), false, 2.0)
	if Engine.is_editor_hint():
		_draw_cracks(self, COLOR.lightened(0.55))

func _draw_cracks(item: CanvasItem, line: Color) -> void:
	var half := size * 0.5
	item.draw_polyline(PackedVector2Array([Vector2(-1.0, -0.3) * half, Vector2(-0.3, -0.1) * half, Vector2(0.0, 0.2) * half, Vector2(0.4, 0.05) * half, Vector2(1.0, 0.4) * half]), line, 2.0)
	item.draw_polyline(PackedVector2Array([Vector2(-0.3, -0.1) * half, Vector2(-0.1, -1.0) * half]), line, 2.0)
	item.draw_polyline(PackedVector2Array([Vector2(0.0, 0.2) * half, Vector2(-0.2, 1.0) * half]), line, 2.0)
