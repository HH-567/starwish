extends Control
## 左下角亮度条（docs/state-machines.md 2.4）：一条横条，金色的是剩下的亮度。
## 低于上限的 low_light_ratio 时变红并呼吸闪烁——屏幕上不写字，亮度就靠这条。
## 数值由 Game.light_changed 推过来，自己不去读玩家。

const MARGIN := 24.0
const WIDTH := 240.0
const HEIGHT := 14.0
const LOW_COLOR := Color("ff5050")
const HIGH_COLOR := Color("ffd75a")
const BACK_COLOR := Color(0.05, 0.06, 0.11, 0.6)
const EDGE_COLOR := Color(0.55, 0.65, 1.0, 0.25)

## 当前亮度 / 上限。测试直接读这两个。
var value := 0.0
var max_value := 1.0

## 美术图：64×16 的槽（九宫格，四边各留 8px），内槽透明，代码往里填。
const ART := "res://assets/art/ui/hud_bar.png"
const PATCH := 8.0

var _tex: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.light_changed.connect(_on_light_changed)
	get_viewport().size_changed.connect(queue_redraw)
	if ResourceLoader.exists(ART):
		_tex = load(ART) as Texture2D

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
	var k := clampf(value / max_value, 0.0, 1.0)
	if _tex != null:
		# 九宫格铺槽：四边不拉伸，中间拉长。
		_nine_slice(back, _tex, PATCH)
		if k > 0.0:
			var c2 := LOW_COLOR.lerp(HIGH_COLOR, smoothstep(0.2, 0.55, k))
			if k < Game.tuning.low_light_ratio:
				c2.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.006))
			draw_rect(Rect2(back.position + Vector2(5, 3), Vector2(maxf((WIDTH - 10.0) * k, 2.0), HEIGHT - 6.0)), c2, true)
		return
	draw_rect(back, BACK_COLOR, true)
	draw_rect(back, EDGE_COLOR, false, 1.0)
	if k <= 0.0:
		return
	var c := LOW_COLOR.lerp(HIGH_COLOR, smoothstep(0.2, 0.55, k))
	if k < Game.tuning.low_light_ratio:
		c.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.006))
	draw_rect(Rect2(pos + Vector2(1, 1), Vector2(maxf((WIDTH - 2.0) * k, 2.0), HEIGHT - 2.0)), c, true)

## 把一张图按九宫格铺到 rect 上（四角原样，四边和中心拉伸）。
func _nine_slice(rect: Rect2, tex: Texture2D, patch: float) -> void:
	var size := tex.get_size()
	var src := [[Vector2.ZERO, Vector2(patch, patch)], [Vector2(size.x - patch, 0), Vector2(patch, patch)]]
	var dst := [[rect.position, Vector2(patch, patch)], [Vector2(rect.end.x - patch, rect.position.y), Vector2(patch, patch)]]
	for i in 2:
		draw_texture_rect_region(tex, Rect2(dst[i][0], dst[i][1]), Rect2(src[i][0], src[i][1]))
	# 上下边 + 中间
	var edge_src := [[Vector2(patch, 0), Vector2(size.x - patch * 2, patch)], [Vector2(patch, size.y - patch), Vector2(size.x - patch * 2, patch)], [Vector2(patch, patch), Vector2(size.x - patch * 2, size.y - patch * 2)]]
	var edge_dst := [
		[Vector2(rect.position.x + patch, rect.position.y), Vector2(rect.size.x - patch * 2, patch)],
		[Vector2(rect.position.x + patch, rect.end.y - patch), Vector2(rect.size.x - patch * 2, patch)],
		[Vector2(rect.position.x + patch, rect.position.y + patch), Vector2(rect.size.x - patch * 2, rect.size.y - patch * 2)],
	]
	for i in 3:
		draw_texture_rect_region(tex, Rect2(edge_dst[i][0], edge_dst[i][1]), Rect2(edge_src[i][0], edge_src[i][1]))
