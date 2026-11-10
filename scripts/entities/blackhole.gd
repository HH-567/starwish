@tool
class_name BlackHole
extends Node2D
## 黑洞（P2，docs/state-machines.md 第 11 节）：半径内给小星一个指向中心的加速度，
## 强度 = strength ÷ max(距离, 最小距离)，弹弓效果由物理自然产生。
## 自己发光：一圈紫黑的漩涡，暗处也认得出。

const COLOR := Color("b48cff")
const CORE := Color("141020")
## 美术图：128×128 紫黑旋涡（黑底转 alpha），有图就用图。
const ART := "res://assets/art/hazards/blackhole.png"

var _art: Sprite2D
const USE_ART := false
## 吸积盘上的光点数。
const DOTS := 110

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
	# 原来的 128 px 旋涡贴图放大到 400 px 直径后全是马赛克，改成程序画（见 _draw）。
	if USE_ART and ResourceLoader.exists(ART):
		var tex := load(ART) as Texture2D
		if tex != null:
			_art = Sprite2D.new()
			_art.texture = tex
			_art.scale = Vector2.ONE * (radius * 2.0 / maxf(tex.get_width(), 1.0))
			add_child(_art)

func _process(delta: float) -> void:
	_t += delta
	if _art != null:
		_art.rotation = _t * 0.35
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
	if _art != null:
		# 只留最外圈作用范围的提示线。
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(COLOR, 0.12), 1.0, true)
		return
	var disk := radius * 0.62
	var hole := radius * 0.13
	# 作用范围：一圈淡淡的，外面一层更淡的光晕（"这片地方不对劲"）
	draw_circle(Vector2.ZERO, disk * 1.05, Color(COLOR, 0.035))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(COLOR, 0.12), 1.0, true)
	# 吸积盘：光点沿螺旋往里掉，越往里转得越快、越亮越白。
	for i in DOTS:
		var seed := float(i) * 2.399963
		var k := fposmod(_t * 0.09 + float(i) / DOTS, 1.0)
		var r := lerpf(disk, hole * 1.15, k * k)
		var ang := seed + k * 7.0 + _t * 0.4
		var p := Vector2.from_angle(ang) * r
		var tangent := Vector2.from_angle(ang + PI * 0.5) * (2.0 + 9.0 * k)
		var c := COLOR.lerp(Color(1.0, 0.95, 1.0), k * k)
		var a := minf(k * 4.0, 1.0) * (0.25 + 0.6 * k)
		draw_line(p - tangent, p, Color(c, a), 1.0 + 1.5 * k, true)
	# 视界：一圈细亮环 + 正中的黑核
	draw_circle(Vector2.ZERO, hole * 1.35, Color(COLOR, 0.25))
	draw_arc(Vector2.ZERO, hole * 1.12, 0.0, TAU, 48, Color(1.0, 0.9, 1.0, 0.8), 2.0, true)
	draw_circle(Vector2.ZERO, hole, CORE)
	draw_circle(Vector2.ZERO, hole * 0.8, Color(0.0, 0.0, 0.0))
