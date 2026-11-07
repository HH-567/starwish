@tool
class_name Bars
extends StaticBody2D
## 栅栏：挡小星，不挡光（docs/state-machines.md 第 17 节）。用来做"照得到、进不去"的笼子。
## 在第 9 层，不在视线射线的 mask 里，也没有遮光体。撞上按黑墙处理，阶段 5 撞碎。
## 栏杆被照到时看得清，暗处只剩一层淡淡的轮廓。

const COLOR := Color("9aa6c8")
const GAP := 8.0
## 美术图：96×32 的横向栏杆，按碰撞盒拉伸。
const ART := "res://assets/art/level/bars.png"

var _art: Sprite2D

@export var size := Vector2(96.0, 32.0):
	set(value):
		size = value
		queue_redraw()

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	collision_layer = Layers.BARS
	collision_mask = 0
	Shapes.add_rect(self, size)
	if ResourceLoader.exists(ART):
		var tex := load(ART) as Texture2D
		if tex != null:
			_art = Sprite2D.new()
			_art.texture = tex
			_art.scale = size / Vector2(tex.get_width(), tex.get_height())
			add_child(_art)
	var faint := Node2D.new()
	faint.material = Lighting.unshaded()
	faint.draw.connect(_draw_bars.bind(faint, Color(COLOR, 0.3)))
	add_child(faint)

func smash() -> void:
	collision_layer = 0
	Debris.spawn(get_parent(), global_position, COLOR, 12, 260.0, 5.0)
	queue_free()

func _draw() -> void:
	if _art != null:
		return
	_draw_bars(self, COLOR)

## 沿长边每隔 GAP 一根栏杆，两条长边是横梁。
func _draw_bars(item: CanvasItem, c: Color) -> void:
	var along_x := size.x >= size.y
	var length := size.x if along_x else size.y
	var width := size.y if along_x else size.x
	var n := maxi(int(length / GAP), 1)
	for i in n + 1:
		var u := -length * 0.5 + length * i / n
		var a := Vector2(u, -width * 0.5)
		var b := Vector2(u, width * 0.5)
		item.draw_line(a if along_x else Vector2(a.y, a.x), b if along_x else Vector2(b.y, b.x), c, 2.0)
	for s in [-1.0, 1.0]:
		var a := Vector2(-length * 0.5, s * width * 0.5)
		var b := Vector2(length * 0.5, s * width * 0.5)
		item.draw_line(a if along_x else Vector2(a.y, a.x), b if along_x else Vector2(b.y, b.x), c, 3.0)
