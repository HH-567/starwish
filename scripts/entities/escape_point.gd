@tool
class_name EscapePoint
extends Area2D
## 逃离点：终章结尾的终点（docs/state-machines.md 第 13 节）。小星跑到这里就停下，噬光者退回黑暗，进正常结局。
## 一扇黎明色的光门，自己发光。

enum State { OPEN, REACHED }

const COLOR := Color("ffe9b0")

@export var size := Vector2(64.0, 160.0):
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
	add_child(Lighting.point_light(260.0, COLOR, 0.9))
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null or state != State.OPEN:
		return
	state = State.REACHED
	player.lock(true)
	Debris.spawn(get_parent(), player.global_position, COLOR, 24, 260.0, 5.0, true)
	var boss := get_tree().get_first_node_in_group(&"boss") as Boss
	if boss != null:
		boss.retreat()

func _draw() -> void:
	# 几道竖着的光，慢慢起伏。
	var rect := Rect2(-size * 0.5, size)
	var pulse := 0.5 + 0.5 * sin(_t * 2.0)
	draw_rect(rect, Color(COLOR, 0.15 + 0.1 * pulse))
	for i in 4:
		var x := lerpf(rect.position.x + 8.0, rect.end.x - 8.0, i / 3.0)
		draw_line(Vector2(x, rect.position.y + 6.0), Vector2(x, rect.end.y - 6.0), Color(COLOR, 0.35 + 0.3 * sin(_t * 3.0 + i)), 3.0)
	draw_rect(rect, COLOR, false, 2.0)
