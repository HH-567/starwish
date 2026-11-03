extends CanvasLayer
## HUD：右上角速度阶段、终章里噬光者在屏幕外时的方向。
## 屏幕上不写字：帮助的效果都发生在世界里（路灯一盏盏亮、花开、光门出现、隧道打开、噬光者被震退），
## HUD 只保留这两个非文字的指示。左上角调试面板只在调试版显示，F3 开关。
## 测试会检查这里除了调试面板没有别的 Label——加提示文字之前先想清楚。

@onready var _debug: Label = $Debug

func _ready() -> void:
	_debug.position = Vector2(16, 12)

func _process(_delta: float) -> void:
	_debug.visible = OS.is_debug_build() and Game.debug_panel
	if not _debug.visible:
		return
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p == null:
		return
	_debug.text = "速度 %d px/s　阶段 %d\n亮度 %.0f / %.0f　衰减%s　%s　已救 %d\n状态 %s　无敌 %.1f　保护 %.1f\n[R] 重置　[Esc] 暂停　[F2] 衰减开关　[F3] 隐藏面板　[F4] 重读数值　[F5] 清空进度" % [
		p.velocity.length(), p.stage,
		p.light, p.light_max, "关" if Game.debug_no_decay else "开",
		"聚光" if p.light_mode == Player.LightMode.FOCUS else "散射", Save.rescued.size(),
		Player.State.keys()[p.state], p.hurt_left, p.grace_left,
	]
