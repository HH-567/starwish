@tool
class_name BlackHole
extends Node2D
## 黑洞（P2，docs/state-machines.md 第 11 节）：半径内给小星一个指向中心的加速度，
## 强度 = strength ÷ max(距离, 最小距离)，弹弓效果由物理自然产生。
## 自己发光：一圈紫黑的漩涡，暗处也认得出。

const COLOR := Color("b48cff")
const CORE := Color("141020")

@export var radius := 200.0:
	set(value):
		radius = value
		queue_redraw()
@export var strength := 48000.0:
	set(value):
		strength = value
		queue_redraw()
## 距离小于它时按它算，免得正中心除以 0、也免得贴脸时加速度爆掉。
@export var min_distance := 40.0

var _t := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	material = Lighting.unshaded()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.state != Player.State.ACTIVE:
		return
	var offset := global_position - player.global_position
	var distance := offset.length()
	if distance > radius or distance < 0.001:
		return
	# 加速度 = strength ÷ max(距离, 最小距离)：越近越强。
	# 交给小星在 step_velocity 里加（不能被松手减速抹掉，否则吸不动）。
	var pull := strength / maxf(distance, min_distance)
	player.push += offset / distance * pull

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(COLOR, 0.35), 2.0, true)
		return
	draw_circle(Vector2.ZERO, 26.0, CORE)
	for k in 3:
		var spin := _t * (0.9 + 0.3 * k) + k * TAU / 3.0
		var ring := radius * (0.45 + 0.18 * k)
		draw_arc(Vector2.ZERO, ring, spin, spin + PI * 1.2, 48, Color(COLOR, 0.5 - 0.1 * k), 2.5, true)
	# 半径边缘一圈淡淡的，提示作用范围。
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(COLOR, 0.12), 1.0, true)
