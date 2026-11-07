@tool
class_name StarShard
extends Area2D
## 小星星：碰到时一次性回 shard_amount 亮度。不存档，重载场景后重新出现。自己发光。

const COLOR := Color("ffe9a0")
const RADIUS := 12.0
## 美术图：24×24 的四角星芒，有图就用图。
const ART := "res://assets/art/items/shard.png"

var _art: Sprite2D
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
	if ResourceLoader.exists(ART):
		var tex := load(ART) as Texture2D
		if tex != null:
			_art = Sprite2D.new()
			_art.texture = tex
			add_child(_art)

func _process(delta: float) -> void:
	_t += delta
	if _art != null:
		# 上下浮动 + 轻微呼吸，和原来程序画的节奏一致。
		_art.position.y = sin(_t * 2.0) * 2.5
		_art.scale = Vector2.ONE * (1.0 + sin(_t * 5.0) * 0.08)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null:
		return
	player.add_light(Game.tuning.shard_amount)
	Debris.spawn(get_parent(), global_position, COLOR, 10, 160.0, 4.0, true)
	queue_free()

func _draw() -> void:
	if _art != null:
		return
	# 上下浮动、一闪一闪的四角星。
	var c := Vector2(0.0, sin(_t * 2.0) * 2.5)
	var r := 7.0 + sin(_t * 5.0) * 0.8
	var k := r * 0.3
	draw_circle(c, r * 1.6, Color(COLOR, 0.15))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(k, -k), c + Vector2(r, 0), c + Vector2(k, k), c + Vector2(0, r), c + Vector2(-k, k), c + Vector2(-r, 0), c + Vector2(-k, -k)]), COLOR)
