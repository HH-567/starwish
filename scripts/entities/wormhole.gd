@tool
class_name Wormhole
extends Node2D
## 虫洞：小星进 A（two_way 时进 B 也行），从另一端出来，速率不变（docs/state-machines.md 第 8 节）。
## A、B 是两个子节点，在编辑器里拖到想要的位置。keep_direction 为假时，出来的方向是出口节点的朝向（+X）。

const COLOR := Color("b48cff")
## 美术图：96×96 双环旋涡（黑底转 alpha），两个出口各挂一张。
const ART := "res://assets/art/hazards/wormhole.png"

var _art := false
## 挂着贴图的几个精灵，只让它们自己转，别转出口节点（出口方向是按节点旋转算的）。
var _art_sprites: Array[Sprite2D] = []
## 科学家的虫洞是白金色的。
const CHARGE_COLOR := Color("fff2c0")
const RADIUS := 20.0
## 出口往外推的距离：出来时已经离开出口的范围。
const PUSH := RADIUS + Player.RADIUS + 4.0

@export var two_way := true:
	set(value):
		two_way = value
		queue_redraw()
@export var keep_direction := true:
	set(value):
		keep_direction = value
		queue_redraw()
## 科学家放下的那个：从这里出来的小星以阶段 5 撞上噬光者能把它撞碎（docs/state-machines.md 第 12 节）。
@export var charge := false:
	set(value):
		charge = value
		queue_redraw()

var _cool_left := 0.0
var _t := 0.0

@onready var _a: Area2D = $A
@onready var _b: Area2D = $B

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	material = Lighting.unshaded()
	for end: Area2D in [_a, _b]:
		end.collision_layer = Layers.TRIGGER
		end.collision_mask = Layers.PLAYER
		end.monitorable = false
		Shapes.add_circle(end, RADIUS)
	_a.body_entered.connect(_on_entered.bind(_b))
	_b.body_entered.connect(_on_entered.bind(_a))
	_add_end_art()

func _process(delta: float) -> void:
	_t += delta
	_cool_left = maxf(_cool_left - delta, 0.0)
	if _art:
		for sprite in _art_sprites:
			if is_instance_valid(sprite):
				sprite.rotation = _t * 0.4
	queue_redraw()

## 两个出口各挂一张旋涡贴图。
func _add_end_art() -> void:
	if not ResourceLoader.exists(ART):
		return
	var tex := load(ART) as Texture2D
	if tex == null:
		return
	for end in [get_node_or_null("A"), get_node_or_null("B")]:
		if end == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.scale = Vector2.ONE * (RADIUS * 2.6 / maxf(tex.get_width(), 1.0))
		end.add_child(sprite)
		_art_sprites.append(sprite)
	_art = true

func _on_entered(body: Node2D, exit: Area2D) -> void:
	var player := body as Player
	if player == null or player.state != Player.State.ACTIVE or _cool_left > 0.0:
		return
	if exit == _a and not two_way:
		return
	var speed := player.velocity.length()
	var dir := Vector2.RIGHT.rotated(exit.global_rotation)
	if keep_direction and speed > 0.0:
		dir = player.velocity / speed
	_cool_left = Player.WARP_TIME + Game.tuning.warp_cooldown
	if charge:
		# 科学家放的那个虫洞是"掉头冲回去"：出来以后直奔噬光者，不看出口朝向。
		# 光靠出口朝向的话，出口和噬光者不在一条走廊上就永远撞不上（F6 进终章就能复现）。
		var boss := get_tree().get_first_node_in_group(&"boss") as Boss
		if boss != null:
			var to_boss := boss.global_position - exit.global_position
			if to_boss.length() > 1.0:
				dir = to_boss.normalized()
		player.charge()
	player.warp(exit.global_position + dir * PUSH, dir * speed)

func _draw() -> void:
	var color := CHARGE_COLOR if charge else COLOR
	for end in [get_node_or_null("A"), get_node_or_null("B")]:
		if end == null:
			continue
		var c: Vector2 = end.position
		# 有美术图就不画程序弧线了（图挂在出口节点下面）。
		if not _art:
			for k in 2:
				var start := _t * (2.0 if k == 0 else -1.4) + k * PI
				draw_arc(c, RADIUS - k * 6.0, start, start + PI * 1.3, 24, Color(color, 0.8 - k * 0.3), 2.5, true)
			draw_circle(c, 4.0, Color(color, 0.6))
		var can_exit: bool = end.name == &"B" or two_way
		if not keep_direction and can_exit:
			# 出口朝向。
			var d := Vector2.RIGHT.rotated(end.rotation)
			draw_line(c + d * (RADIUS + 2.0), c + d * (RADIUS + 12.0), color, 2.0)
