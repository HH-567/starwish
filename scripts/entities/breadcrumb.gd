@tool
class_name Breadcrumb
extends Node2D
## 路标：一点会呼吸的微光，只用来引路。不挡路、不触发、不存档，也不捡。
## 教学关用它把"往这边走"铺出来，省掉屏幕上的字（docs/level-data-format.md 第 10 节）。
## 和小星星区分开：这个是冷白色的小点，没有星角。

const COLOR := Color("bcd4ff")
## 呼吸一次多久，秒。
const PERIOD := 2.6

@export var radius := 3.0:
	set(value):
		radius = value
		queue_redraw()

var _t := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	material = Lighting.unshaded()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var k := 0.5 + 0.5 * sin(_t * TAU / PERIOD)
	# 外面一层很淡的光晕，里面一点实心；越近越亮。
	draw_circle(Vector2.ZERO, radius * (1.6 + 0.5 * k), Color(COLOR, 0.06 + 0.08 * k))
	draw_circle(Vector2.ZERO, radius * (0.85 + 0.15 * k), Color(COLOR, 0.45 + 0.35 * k))
