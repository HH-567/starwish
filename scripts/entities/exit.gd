@tool
class_name Exit
extends Area2D
## 出口：一直开着，小星进入时发 chapter_cleared（docs/state-machines.md 第 7 节）。
## 没有必救的人，没救的人就留在这一章里。

enum State { OPEN, CLEARED }

const COLOR := Color("ffd75a")

@export var size := Vector2(64.0, 64.0):
	set(value):
		size = value
		queue_redraw()

var state := State.OPEN
var _t := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	material = Lighting.unshaded()
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	Shapes.add_rect(self, size)
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not body is Player or state != State.OPEN:
		return
	state = State.CLEARED
	Debris.spawn(get_parent(), global_position, COLOR, 24, 260.0, 5.0, true)
	var chapter := Save.chapter_of(self)
	Game.chapter_cleared.emit(chapter.get("chapter_id") if chapter != null else &"")

func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	draw_rect(rect, Color(COLOR, 0.18 + 0.12 * pulse))
	draw_rect(rect, COLOR, false, 2.0)
	draw_rect(rect.grow(-6.0 - 4.0 * pulse), Color(COLOR, 0.5), false, 1.5)
