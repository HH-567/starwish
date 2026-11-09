@tool
class_name IronDoor
extends StaticBody2D
## 铁门：锁匠被救后打开（docs/state-machines.md 第 16 节）。关着时挡路挡光，任何速度都撞不开。
## 开门不单独存档，跟着锁匠走：锁匠救过 → 小星走近时门自己打开；没救 → 永远关着。
## 门是黑的（在自己的阴影里），边框和锁孔自己微微发光，暗处也认得出。

enum State { CLOSED, OPEN }

const COLOR := Color("2c3350")
const EDGE := Color("8a93b8")
## 锁匠救过之后，小星进到这个距离以内门就开（像素）。
const OPEN_RANGE := 80.0
## 开门动画多长（秒）。
const OPEN_TIME := 0.30
## 美术图：128×32 的横向闸门，按碰撞盒拉伸。
const ART := "res://assets/art/level/iron_door.png"

var _art: Sprite2D

@export var size := Vector2(96.0, 32.0):
	set(value):
		size = value
		queue_redraw()

## 小星撞墙时查这个：阶段 5 也撞不碎。
var unbreakable := true
var state := State.CLOSED
## 锁匠已经救过：这扇门可以被小星"靠近打开"。
var _can_open := false
## 开门动画剩余时间。
var _open_left := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_can_open = Save.has_role(&"locksmith")
	collision_layer = Layers.WORLD
	collision_mask = 0
	Shapes.add_rect(self, size)
	Shapes.add_occluder(self, size)
	_load_art()
	var edge := Node2D.new()
	edge.material = Lighting.unshaded()
	edge.draw.connect(_draw_edge.bind(edge, Color(EDGE, 0.5)))
	add_child(edge)
	Game.npc_rescued.connect(_on_npc_rescued)

func _load_art() -> void:
	if not ResourceLoader.exists(ART):
		return
	var tex := load(ART) as Texture2D
	if tex == null:
		return
	_art = Sprite2D.new()
	_art.texture = tex
	_art.material = Lighting.unshaded()
	_art.scale = size / Vector2(tex.get_width(), tex.get_height())
	add_child(_art)

func _physics_process(delta: float) -> void:
	if _open_left > 0.0:
		_open_left -= delta
		# 门往上收：贴图和边框往上挪，同时淡出
		var k := 1.0 - clampf(_open_left / OPEN_TIME, 0.0, 1.0)
		if _art != null:
			_art.position.y = -size.y * k
			_art.modulate.a = 1.0 - k
		queue_redraw()
		if _open_left <= 0.0:
			queue_free()
		return
	if state != State.CLOSED or not _can_open:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	if global_position.distance_to(player.global_position) <= OPEN_RANGE:
		open()

## 锁匠开过门：碰撞立刻关掉（小星马上能过），视觉上有一段 0.3 秒的收门动画。
func open() -> void:
	if state == State.OPEN:
		return
	state = State.OPEN
	collision_layer = 0
	_open_left = OPEN_TIME
	Debris.spawn(get_parent(), global_position, EDGE, 16, 220.0, 5.0, true)
	Audio.play_at(&"door", global_position)

func _on_npc_rescued(id: String) -> void:
	# 锁匠被救只代表"这扇门有人管了"；实际打开还是等小星走到附近（门匠只在近处开门）
	if Save.rescued.get(id, &"") == &"locksmith":
		_can_open = true

func _draw() -> void:
	if _art != null:
		return
	draw_rect(Rect2(-size * 0.5, size), COLOR)
	if Engine.is_editor_hint():
		_draw_edge(self, EDGE)

func _draw_edge(item: CanvasItem, c: Color) -> void:
	item.draw_rect(Rect2(-size * 0.5, size).grow(-2.0), c, false, 2.0)
	# 锁孔。
	item.draw_circle(Vector2(0.0, -2.0), 3.0, c)
	item.draw_line(Vector2(0.0, -1.0), Vector2(0.0, 5.0), c, 2.0)
