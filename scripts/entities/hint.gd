@tool
class_name Hint
extends Area2D
## 走进来就浮出一行提示（HUD 显示），只响一次。文字查 scripts/data/hints.gd，地图里的数字 1–5 摆位。
## 只做提示：没有碰撞、不挡光、不影响玩法，也不存档（重开这一章会再出现一次）。

const SIZE := Vector2(96.0, 96.0)
const SHOW_COLOR := Color(1.0, 0.94, 0.72, 0.25)

## scripts/data/hints.gd 里 TEXT 的键。
@export var hint_id := &""

var _used := false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	material = Lighting.unshaded()
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	Shapes.add_rect(self, SIZE)
	body_entered.connect(_on_body_entered)

func text() -> String:
	return String(Hints.TEXT.get(hint_id, ""))

func _on_body_entered(body: Node2D) -> void:
	if _used or not body is Player:
		return
	_used = true
	Game.hint_shown.emit(text())

func _draw() -> void:
	# 只在编辑器里画个框，方便摆位；游戏里什么都不画。
	if Engine.is_editor_hint():
		draw_rect(Rect2(-SIZE * 0.5, SIZE), SHOW_COLOR, false, 1.0)
