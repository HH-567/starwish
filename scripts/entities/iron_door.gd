@tool
class_name IronDoor
extends StaticBody2D
## 铁门：锁匠被救后打开（docs/state-machines.md 第 16 节）。关着时挡路挡光，任何速度都撞不开。
## 开门不单独存档，跟着锁匠走：章节加载时锁匠已经救了，门就不出现。
## 门是黑的（在自己的阴影里），边框和锁孔自己微微发光，暗处也认得出。

enum State { CLOSED, OPEN }

const COLOR := Color("2c3350")
const EDGE := Color("8a93b8")

@export var size := Vector2(96.0, 32.0):
	set(value):
		size = value
		queue_redraw()

## 小星撞墙时查这个：阶段 5 也撞不碎。
var unbreakable := true
var state := State.CLOSED

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if Save.has_role(&"locksmith"):
		state = State.OPEN
		queue_free()
		return
	collision_layer = Layers.WORLD
	collision_mask = 0
	Shapes.add_rect(self, size)
	Shapes.add_occluder(self, size)
	var edge := Node2D.new()
	edge.material = Lighting.unshaded()
	edge.draw.connect(_draw_edge.bind(edge, Color(EDGE, 0.5)))
	add_child(edge)
	Game.npc_rescued.connect(_on_npc_rescued)

func open() -> void:
	if state == State.OPEN:
		return
	state = State.OPEN
	collision_layer = 0
	Debris.spawn(get_parent(), global_position, EDGE, 16, 220.0, 5.0, true)
	queue_free()

func _on_npc_rescued(id: String) -> void:
	if Save.rescued.get(id, &"") == &"locksmith":
		open()

func _draw() -> void:
	draw_rect(Rect2(-size * 0.5, size), COLOR)
	if Engine.is_editor_hint():
		_draw_edge(self, EDGE)

func _draw_edge(item: CanvasItem, c: Color) -> void:
	item.draw_rect(Rect2(-size * 0.5, size).grow(-2.0), c, false, 2.0)
	# 锁孔。
	item.draw_circle(Vector2(0.0, -2.0), 3.0, c)
	item.draw_line(Vector2(0.0, -1.0), Vector2(0.0, 5.0), c, 2.0)
