@tool
class_name Lamp
extends Node2D
## 守夜人那段赛道的路灯，是守夜人帮助点的子节点：守夜人没救就不出现。
## 小星经过守夜人时，由近到远一盏盏亮起来（docs/state-machines.md 第 18 节）。灭着时只有淡淡的灯杆轮廓。

const POLE := Color("8a93b8")
const LIT := Color("ffd98a")
const RADIUS := 170.0
const HEAD := Vector2(0.0, -14.0)

var lit := false
## 还要等多久亮；小于 0 = 没在等。
var _delay_left := -1.0
var _light: PointLight2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	material = Lighting.unshaded()
	_light = Lighting.point_light(RADIUS, LIT, 0.8)
	_light.position = HEAD
	_light.visible = false
	add_child(_light)

## delay 秒后亮。
func light_up(delay: float) -> void:
	if not lit and _delay_left < 0.0:
		_delay_left = delay

func _process(delta: float) -> void:
	if _delay_left < 0.0:
		return
	_delay_left -= delta
	if _delay_left < 0.0:
		lit = true
		_light.visible = true
		Debris.spawn(get_parent(), global_position + HEAD, LIT, 6, 90.0, 3.0, true)
		queue_redraw()

func _draw() -> void:
	var pole := Color(POLE, 0.8 if lit else 0.35)
	draw_line(Vector2(0.0, 14.0), HEAD, pole, 2.0)
	draw_line(Vector2(-6.0, 14.0), Vector2(6.0, 14.0), pole, 2.0)
	if lit:
		draw_circle(HEAD, 10.0, Color(LIT, 0.25))
		draw_circle(HEAD, 4.5, LIT)
	else:
		draw_arc(HEAD, 4.5, 0.0, TAU, 12, pole, 1.5)
