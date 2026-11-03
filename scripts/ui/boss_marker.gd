extends Control
## 噬光者在屏幕外时，在屏幕边上它那个方向画一对红眼睛；离得越近越大、越亮、闪得越快。

const EYE := Color("ff5a7a")
const MARGIN := 28.0
## 离小星超过这么远就不画。
const FAR := 1400.0

var _t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var boss := get_tree().get_first_node_in_group(&"boss") as Boss
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if boss == null or player == null or boss.state != Boss.State.CHASE:
		return
	var screen := get_viewport_rect()
	var at := boss.get_global_transform_with_canvas().origin
	if screen.grow(Boss.RADIUS * 0.5).has_point(at):
		return
	var dist := boss.global_position.distance_to(player.global_position)
	if dist > FAR:
		return
	# 从屏幕中心朝它的方向，停在离边 MARGIN 的地方。
	var center := screen.get_center()
	var dir := (at - center).normalized()
	var half := screen.size * 0.5 - Vector2(MARGIN, MARGIN)
	var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var p := center + dir * k
	var near := 1.0 - dist / FAR
	var blink := 0.7 + 0.3 * sin(_t * lerpf(4.0, 14.0, near))
	var r := lerpf(14.0, 24.0, near)
	draw_circle(p, r, Color(EYE, 0.18 * blink))
	# 两只眼睛，横在它过来的方向上。
	var side := dir.orthogonal() * r * 0.35
	for s: float in [-1.0, 1.0]:
		draw_circle(p + side * s, lerpf(2.5, 4.5, near), Color(EYE, lerpf(0.6, 1.0, near) * blink))
