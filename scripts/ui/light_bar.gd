extends Control
## 左下角亮度条（docs/state-machines.md 2.4）：一条横条，金色的是剩下的亮度。
## 低于上限的 low_light_ratio 时变红并呼吸闪烁——屏幕上不写字，亮度就靠这条。
## 数值由 Game.light_changed 推过来，自己不去读玩家。

const MARGIN := 24.0
const WIDTH := 240.0
const HEIGHT := 9.0
const LOW_COLOR := Color("ff5050")
const HIGH_COLOR := Color("ffd75a")
const BACK_COLOR := Color(0.05, 0.06, 0.11, 0.6)
const EDGE_COLOR := Color(0.55, 0.65, 1.0, 0.25)

## 当前亮度 / 上限。测试直接读这两个。
var value := 0.0
var max_value := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.light_changed.connect(_on_light_changed)
	get_viewport().size_changed.connect(queue_redraw)

func _process(_delta: float) -> void:
	# 低亮度时呼吸闪烁，得每帧重画
	if max_value > 0.0 and value <= max_value * Game.tuning.low_light_ratio:
		queue_redraw()

func _on_light_changed(v: float, m: float) -> void:
	value = v
	max_value = maxf(m, 0.001)
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport_rect().size
	var pos := Vector2(MARGIN, vp.y - MARGIN - HEIGHT)
	var back := Rect2(pos, Vector2(WIDTH, HEIGHT))
	draw_rect(back, BACK_COLOR, true)
	draw_rect(back, EDGE_COLOR, false, 1.0)
	var k := clampf(value / max_value, 0.0, 1.0)
	if k <= 0.0:
		return
	var c := LOW_COLOR.lerp(HIGH_COLOR, smoothstep(0.2, 0.55, k))
	if k < Game.tuning.low_light_ratio:
		c.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.006))
	draw_rect(Rect2(pos + Vector2(1, 1), Vector2(maxf((WIDTH - 2.0) * k, 2.0), HEIGHT - 2.0)), c, true)
