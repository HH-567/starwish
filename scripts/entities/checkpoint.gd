@tool
class_name Checkpoint
extends Area2D
## 检查点：小星进入后成为当前检查点，死亡或按 R 从这里出来（docs/state-machines.md 第 6 节）。
## 只记最新的一个。自己发光：没点亮时是淡蓝的灯座，点亮后是暖黄的灯。

enum State { INACTIVE, ACTIVE }

const IDLE := Color("8fb4ff")
const LIT := Color("ffd75a")
const SIZE := Vector2(32.0, 48.0)

var state := State.INACTIVE
var save_id := ""

var _lamp: PointLight2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"checkpoint")
	material = Lighting.unshaded()
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	Shapes.add_rect(self, SIZE)
	save_id = Save.id_of(self)
	_lamp = Lighting.point_light(80.0, LIT, 0.6)
	add_child(_lamp)
	_set_state(State.ACTIVE if Save.checkpoint == save_id else State.INACTIVE)
	body_entered.connect(_on_body_entered)
	Game.checkpoint_reached.connect(_on_checkpoint_reached)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and state == State.INACTIVE:
		Save.checkpoint = save_id
		_set_state(State.ACTIVE)
		Game.checkpoint_reached.emit(save_id)

func _on_checkpoint_reached(id: String) -> void:
	if id != save_id:
		_set_state(State.INACTIVE)

func _set_state(next: State) -> void:
	state = next
	_lamp.visible = next == State.ACTIVE
	queue_redraw()

func _draw() -> void:
	# 灯柱加一盏菱形的灯。
	var lit := state == State.ACTIVE
	var c := LIT if lit else Color(IDLE, 0.6)
	draw_line(Vector2(0, 22), Vector2(0, -6), c, 2.0)
	draw_line(Vector2(-7, 22), Vector2(7, 22), c, 2.0)
	var lamp := PackedVector2Array([Vector2(0, -20), Vector2(7, -12), Vector2(0, -4), Vector2(-7, -12)])
	if lit:
		draw_colored_polygon(lamp, c)
	else:
		lamp.append(lamp[0])
		draw_polyline(lamp, c, 1.5)
