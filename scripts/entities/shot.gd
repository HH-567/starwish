class_name Shot
extends CharacterBody2D
## 影鬼打出的弹幕（docs/state-machines.md 第 12 节）：直线飞，撞墙反弹，
## 弹满 `max_bounces` 次就自己熄灭。
## 打到小星 → 掉亮度；打到影鬼（包括打出去的那只）→ 那只阵亡——所以贴墙打一枪再躲开，
## 弹幕会绕回来把它自己打掉，这是拆影鬼的正规解法。

const CORE_COLOR := Color("ffb08a")
const TRAIL_COLOR := Color("ff5a4a")
const RADIUS := 6.0

var direction := Vector2.LEFT
var speed := 520.0
var bounces := 0
var max_bounces := 3
var damage := 15.0
var life := 5.0

func _ready() -> void:
	material = Lighting.unshaded()
	collision_layer = 0
	collision_mask = Layers.WALLS | Layers.PLAYER | Layers.ENEMY
	Shapes.add_circle(self, RADIUS)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var hit := move_and_collide(direction * speed * delta)
	if hit != null:
		_hit(hit)
	queue_redraw()

func _hit(hit: KinematicCollision2D) -> void:
	var other := hit.get_collider()
	if other is Player:
		var player := other as Player
		player.blast(damage)
		# 打中还会把小星往弹幕方向推一把；打死了就不推了。
		if player.state == Player.State.ACTIVE:
			player.velocity += direction * Game.tuning.shot_knockback
		_burst()
		return
	if other is Enemy:
		(other as Enemy)._kill(&"shot")
		_burst()
		return
	# 墙：按法线反射，弹满就灭
	direction = direction.bounce(hit.get_normal()).normalized()
	bounces += 1
	Debris.spawn(get_parent(), hit.get_position(), TRAIL_COLOR, 4, 160.0, 3.0, true)
	if bounces > max_bounces:
		_burst()

func _burst() -> void:
	Debris.spawn(get_parent(), global_position, CORE_COLOR, 8, 200.0, 4.0, true)
	queue_free()

func _draw() -> void:
	draw_line(-direction * 16.0, Vector2.ZERO, Color(TRAIL_COLOR, 0.45), 3.0)
	draw_circle(Vector2.ZERO, RADIUS, CORE_COLOR)
	draw_circle(Vector2.ZERO, RADIUS * 0.5, Color(1, 1, 1, 0.9))
