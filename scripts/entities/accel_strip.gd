@tool
class_name AccelStrip
extends Area2D
## 加速带：顺着方向（节点的 +X）进入时，沿带方向的速度提到至少 target_speed（docs/state-machines.md 第 9 节）。
## 园丁在终章种的花也是加速带（flowers 为真），是他帮助点的子节点。

const COLOR := Color("8fd3ff")
const FLOWER := Color("ffb7d5")
const CHEVRON_GAP := 24.0
const FLOWER_GAP := 20.0
## 园丁的花有美术图时直接平铺它。
const FLOWER_ART := "res://assets/art/level/flower_accel.png"
const ARROW_ART := "res://assets/art/level/accel_arrow.png"

var _flower_tex: Texture2D
var _arrow_tex: Texture2D

## x = 沿方向的长度，y = 宽度。
@export var size := Vector2(64.0, 192.0):
	set(value):
		size = value
		queue_redraw()
@export var target_speed := 920.0
## 画成一片发光的花，不画成箭头。
@export var flowers := false:
	set(value):
		flowers = value
		queue_redraw()

var _t := 0.0
## 铺没铺出来。终章一开始是 false（路还没点亮），守夜人来了才一段段 deploy。
var deployed := true
## 亮起动画剩余时间，>0 时画一层白光。
var _appear := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# 自己发光，暗处也看得见。
	material = Lighting.unshaded()
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	Shapes.add_rect(self, size)
	body_entered.connect(_on_body_entered)
	_apply()

## 收起：画都不画、也触发不了。
func undeploy() -> void:
	deployed = false
	_apply()

## 铺出来：亮起并开始生效。
func deploy() -> void:
	if deployed:
		return
	deployed = true
	_appear = 0.4
	_apply()

func _apply() -> void:
	visible = deployed
	collision_layer = Layers.TRIGGER if deployed else 0
	monitoring = deployed
	if _flower_tex == null and ResourceLoader.exists(FLOWER_ART):
		_flower_tex = load(FLOWER_ART) as Texture2D
	if _arrow_tex == null and ResourceLoader.exists(ARROW_ART):
		_arrow_tex = load(ARROW_ART) as Texture2D
	queue_redraw()

func _process(delta: float) -> void:
	if not deployed:
		return
	_t += delta
	if _appear > 0.0:
		_appear = maxf(_appear - delta, 0.0)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player != null:
		player.boost(Vector2.RIGHT.rotated(global_rotation), target_speed)

func _draw() -> void:
	var half := size * 0.5
	var c := FLOWER if flowers else COLOR
	# 有美术图就平铺美术图，没有就画原来的几何图形。
	if flowers and _flower_tex != null:
		draw_texture_rect(_flower_tex, Rect2(-half, size), true)
		if _appear > 0.0:
			draw_rect(Rect2(-half, size), Color(1, 1, 1, 0.55 * (_appear / 0.4)), true)
		return
	if not flowers and _arrow_tex != null:
		draw_texture_rect(_arrow_tex, Rect2(-half, size), true)
		if _appear > 0.0:
			draw_rect(Rect2(-half, size), Color(1, 1, 1, 0.55 * (_appear / 0.4)), true)
		return
	draw_rect(Rect2(-half, size), Color(c, 0.12))
	for i in maxi(int(size.x / CHEVRON_GAP), 1):
		var x := -half.x + fposmod(i * CHEVRON_GAP + _t * 60.0, size.x)
		draw_polyline(PackedVector2Array([Vector2(x - 12.0, -half.y * 0.6), Vector2(x, 0.0), Vector2(x - 12.0, half.y * 0.6)]), Color(c, 0.35 if flowers else 0.7), 3.0)
	if flowers:
		# 一格一朵，四片花瓣跟着风轻轻转。
		var cols := maxi(int(size.x / FLOWER_GAP), 1)
		var rows := maxi(int(size.y / FLOWER_GAP), 1)
		for i in cols:
			for j in rows:
				var p := -half + Vector2((i + 0.5) * size.x / cols, (j + 0.5) * size.y / rows)
				var spin := _t * 0.8 + i * 1.7 + j * 2.3
				for k in 4:
					draw_circle(p + Vector2.from_angle(spin + TAU * k / 4.0) * 3.5, 2.5, Color(FLOWER, 0.75))
				draw_circle(p, 1.8, Color("fff2c0"))
	# 刚铺出来的一瞬间：整条亮一下
	if _appear > 0.0:
		draw_rect(Rect2(-half, size), Color(1, 1, 1, 0.55 * (_appear / 0.4)), true)
