class_name RoadLighter
extends Node2D
## 点灯的人（终章开头站在出门口）：小星经过时他把整条赛道的加速带一段段铺出来。
## 不是一个"可救的小人"——他没有存档 id，也不吃光；只是站在那儿提着一盏灯。
## 走过之后发 Game.road_light，终章负责做镜头左移 + 逐段铺带。

const BODY := Color("e8eefc")
const LAMP := Color("ffd75a")
const TRIGGER_HEIGHT := 600.0

signal lit

var _done := false

func _ready() -> void:
	material = Lighting.unshaded()
	add_to_group(&"road_lighter")
	var body := Area2D.new()
	body.collision_layer = 0
	body.collision_mask = Layers.PLAYER
	body.monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48.0, TRIGGER_HEIGHT)
	shape.shape = rect
	body.add_child(shape)
	body.body_entered.connect(_on_body_entered)
	add_child(body)

func _on_body_entered(node: Node2D) -> void:
	if _done or not node is Player:
		return
	_done = true
	lit.emit()
	Game.road_light.emit(global_position)
	queue_redraw()

func _draw() -> void:
	# 一盏灯 + 一个站着的人：和赛道里的小人同一套画法，好认
	draw_circle(Vector2(10.0, -6.0), 26.0, Color(LAMP, 0.10))
	draw_circle(Vector2(10.0, -6.0), 12.0, Color(LAMP, 0.22))
	draw_circle(Vector2(10.0, -6.0), 4.0, LAMP)
	Npc.draw_figure(self, true)
	if _done:
		# 铺完之后灯更亮一点，表示"路已经点着了"
		draw_circle(Vector2(10.0, -6.0), 30.0, Color(LAMP, 0.08))
