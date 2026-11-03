@tool
class_name StarShard
extends Area2D
## 小星星：碰到时一次性回 shard_amount 亮度。不存档，重载场景后重新出现。自己发光。

const COLOR := Color("ffe9a0")
const RADIUS := 12.0

var _t := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	material = Lighting.unshaded()
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	Shapes.add_circle(self, RADIUS)
	body_entered.connect(_on_body_entered)
	_t = randf() * TAU

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	player.add_light(Game.tuning.shard_amount)
	Debris.spawn(get_parent(), global_position, COLOR, 10, 160.0, 4.0, true)
	queue_free()

func _draw() -> void:
	# 上下浮动、一闪一闪的四角星。
	var c := Vector2(0.0, sin(_t * 2.0) * 2.5)
	var r := 7.0 + sin(_t * 5.0) * 0.8
	var k := r * 0.3
	draw_circle(c, r * 1.6, Color(COLOR, 0.15))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(k, -k), c + Vector2(r, 0), c + Vector2(k, k), c + Vector2(0, r), c + Vector2(-k, k), c + Vector2(-r, 0), c + Vector2(-k, -k)]), COLOR)
