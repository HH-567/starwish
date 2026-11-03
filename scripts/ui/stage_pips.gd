extends Control
## 右上角速度阶段：5 个菱形，当前档最亮最大，其他档淡色。

const MARGIN := 24.0
const GAP := 30.0
const R := 9.0

var _stage := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.speed_stage_changed.connect(_on_stage_changed)
	get_viewport().size_changed.connect(queue_redraw)

func _on_stage_changed(stage: int) -> void:
	_stage = stage
	queue_redraw()

func _draw() -> void:
	var right := get_viewport_rect().size.x - MARGIN
	for i in 5:
		var s := i + 1
		var center := Vector2(right - (4 - i) * GAP - R, MARGIN + R)
		var r := R * (1.4 if s == _stage else 1.0)
		var pts := PackedVector2Array([center + Vector2(0, -r), center + Vector2(r, 0), center + Vector2(0, r), center + Vector2(-r, 0)])
		var c := Game.tuning.stage_color(s)
		draw_colored_polygon(pts, c if s == _stage else Color(c, 0.3))
