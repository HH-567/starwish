@tool
class_name ShadowVine
extends StaticBody2D
## 影藤：挡路也挡光，被聚光照够 vine_burn_time 秒就烧断（docs/state-machines.md 第 4 节）。
## 散射照到没有效果。藤条自己微微发紫光，暗处也认得出；烧的时候变成橙色。

enum State { INTACT, BURNING, BURNT }

const COLOR := Color("1c1026")
const STRAND := Color("6a3d8f")
const EMBER := Color("ff8a3d")

@export var size := Vector2(32.0, 96.0):
	set(value):
		size = value
		queue_redraw()

var state := State.INTACT
var burn := 0.0
var save_id := ""

var _lit_frame := -10
var _aura: Node2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	save_id = Save.id_of(self)
	if Save.burnt.has(save_id):
		state = State.BURNT
		queue_free()
		return
	add_to_group(&"light_receiver")
	collision_layer = Layers.VINE
	collision_mask = 0
	Shapes.add_rect(self, size)
	Shapes.add_occluder(self, size)
	_aura = Node2D.new()
	_aura.material = Lighting.unshaded()
	_aura.draw.connect(_draw_aura)
	add_child(_aura)

func receive_light(mode: int, _delta: float) -> void:
	if mode == Player.LightMode.FOCUS:
		_lit_frame = Engine.get_physics_frames()

## 影藤上离 from 最近的点，往里收 1 像素，视线射线才会打中影藤自己。
func light_target(from: Vector2) -> Vector2:
	var half := size * 0.5 - Vector2.ONE
	return to_global(to_local(from).clamp(-half, half))

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or state == State.BURNT:
		return
	var lit := Engine.get_physics_frames() - _lit_frame <= 1
	if state == State.INTACT and lit:
		state = State.BURNING
	if state == State.BURNING:
		burn += delta if lit else -delta * Game.tuning.progress_decay
		if burn <= 0.0:
			burn = 0.0
			state = State.INTACT
		elif burn >= Game.tuning.vine_burn_time:
			_burn_out()
			return
	_aura.queue_redraw()

## 阶段 5 撞上也会断。
func smash() -> void:
	_burn_out()

func _burn_out() -> void:
	state = State.BURNT
	collision_layer = 0
	Save.burnt[save_id] = true
	Debris.spawn(get_parent(), global_position, EMBER, 16, 200.0, 5.0, true)
	Game.vine_burnt.emit(save_id)
	queue_free()

## 沿长边方向的几根波浪线。
func _strands() -> Array[PackedVector2Array]:
	var along_x := size.x >= size.y
	var length := size.x if along_x else size.y
	var width := size.y if along_x else size.x
	var lines: Array[PackedVector2Array] = []
	var n := maxi(int(length / 8.0), 2)
	for k in 3:
		var pts := PackedVector2Array()
		for i in n + 1:
			var u := -length * 0.5 + length * i / n
			var w := sin(u * 0.13 + k * 2.1) * width * 0.32
			pts.append(Vector2(u, w) if along_x else Vector2(w, u))
		lines.append(pts)
	return lines

func _draw() -> void:
	draw_rect(Rect2(-size * 0.5, size), COLOR)
	if Engine.is_editor_hint():
		for pts in _strands():
			draw_polyline(pts, STRAND, 3.0)

func _draw_aura() -> void:
	var heat := clampf(burn / Game.tuning.vine_burn_time, 0.0, 1.0)
	var flicker := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.03)
	var c := STRAND.lerp(EMBER, heat)
	c.a = lerpf(0.55, 1.0, heat) * (flicker if heat > 0.0 else 1.0)
	for pts in _strands():
		_aura.draw_polyline(pts, c, 2.5 + heat * 1.5)
