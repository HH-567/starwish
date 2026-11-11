extends Control
## 右上角速度阶段：5 个菱形，当前档最亮最大，其他档淡色。
## 右边要给齿轮（设置按钮，44×44，锚在右边往里 64）让位，不然第 5 档会叠在齿轮上。

const MARGIN := 24.0
## 从右边边缘往里收这么多：齿轮占 [W-64, W-20]，菱形右沿停在 W-76，留 12px 空隙。
const RIGHT_INSET := 76.0
const GAP := 30.0
const R := 9.0
## 美术图：16×16 的菱形，代码用 modulate 染成 5 档颜色。
const ART := "res://assets/art/ui/hud_diamond.png"

var _tex: Texture2D
var _stage := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.speed_stage_changed.connect(_on_stage_changed)
	get_viewport().size_changed.connect(queue_redraw)
	if ResourceLoader.exists(ART):
		_tex = load(ART) as Texture2D

func _on_stage_changed(stage: int) -> void:
	_stage = stage
	queue_redraw()

func _draw() -> void:
	var right := get_viewport_rect().size.x - RIGHT_INSET
	for i in 5:
		var s := i + 1
		var center := Vector2(right - (4 - i) * GAP - R, MARGIN + R)
		var r := R * (1.4 if s == _stage else 1.0)
		var c := Game.tuning.stage_color(s)
		if _tex != null:
			var box := Vector2(r, r) * 2.0
			draw_texture_rect(_tex, Rect2(center - box * 0.5, box), false, Color(c, 1.0 if s == _stage else 0.35))
			continue
		var pts := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])
		draw_colored_polygon(pts, c if s == _stage else Color(c, 0.3))
