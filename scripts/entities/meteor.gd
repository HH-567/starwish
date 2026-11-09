@tool
class_name Meteor
extends Node2D
## 流星（P2，docs/state-machines.md 第 10 节）：IDLE → WARNING（地上出现红圈）→ IMPACT（只判定一帧）→
## COOLDOWN → WARNING。圈里的小星按阶段 2 撞墙扣亮度。
## 数值就在下面几个 export 上（按 docs 第 3 节，这是实体自己的参数）。

enum State { COOLDOWN, WARNING, IMPACT }

const WARN_COLOR := Color("ff5050")
const IMPACT_COLOR := Color("ffd08a")

## 隔多久来一颗、预警多久（秒）、判定半径（px）。按 docs 第 3 节，这是实体自己的参数。
@export var interval := 2.6
@export var warn_time := 1.1
@export var radius := 80.0

var state := State.COOLDOWN
var time := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	material = Lighting.unshaded()
	# 一上来先等一个间隔，别在读档/出生那一刻就砸下来。
	_set_state(State.COOLDOWN)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	time += delta
	match state:
		State.COOLDOWN:
			if time >= interval:
				_set_state(State.WARNING)
				# 预警声按预警时长变调：哨音落到底的那一刻正好砸下来。
				Audio.play_at(&"meteor_warn", global_position, WARN_SOUND_TIME / maxf(warn_time, 0.1))
		State.WARNING:
			if time >= warn_time:
				_set_state(State.IMPACT)
				_impact()
		State.IMPACT:
			# 判定只在一帧里做，之后进入冷却。
			if time >= 0.12:
				_set_state(State.COOLDOWN)
	queue_redraw()

## meteor_warn.wav 本身的长度（从开始到落地那一下）。
const WARN_SOUND_TIME := 1.1

func _impact() -> void:
	Debris.spawn(get_parent(), global_position, IMPACT_COLOR, 18, 300.0, 6.0, true)
	Audio.play_at(&"meteor", global_position)
	Game.player_hit.emit(&"meteor")
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.state != Player.State.ACTIVE:
		return
	if player.global_position.distance_to(global_position) <= radius + Player.RADIUS:
		# 和阶段 2 撞墙一样的代价。
		player.blast(Game.tuning.s2_damage)

func _set_state(next: State) -> void:
	state = next
	time = 0.0
	queue_redraw()

func _draw() -> void:
	# 编辑器里画个圈方便摆位。
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(WARN_COLOR, 0.3), 2.0, true)
		return
	match state:
		State.WARNING:
			var k := clampf(time / maxf(warn_time, 0.01), 0.0, 1.0)
			# 圈从大收到小，最后一刻最亮。
			draw_circle(Vector2.ZERO, radius, Color(WARN_COLOR, 0.06 + 0.12 * k))
			draw_arc(Vector2.ZERO, lerpf(radius, radius * 0.35, k), 0.0, TAU, 48, Color(WARN_COLOR, 0.35 + 0.55 * k), 3.0, true)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(WARN_COLOR, 0.25), 1.5, true)
		State.IMPACT:
			draw_circle(Vector2.ZERO, radius, Color(IMPACT_COLOR, 0.5))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, IMPACT_COLOR, 4.0, true)
