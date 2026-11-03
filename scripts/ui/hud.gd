extends CanvasLayer
## HUD：右上角速度阶段、终章里噬光者在屏幕外时的方向、帮助触发时浮出的一行字是正式 UI；
## 左上角调试面板只在调试版显示，F3 开关。

## 帮助触发时说一句他做了什么（docs/state-machines.md 第 18 节）。
const HELP_TEXT := {
	&"watchman": "守夜人点亮了路灯，替你挡一次",
	&"gardener": "园丁的花开了",
	&"doctor": "医生让你的光回满了",
	&"painter": "画家画了一扇光门",
	&"miner": "矿工挖开了隧道",
	&"musician": "乐手的声波震退了噬光者",
	&"listener": "听众跟着节拍为你加油",
	&"clockmaker": "钟表匠让噬光者慢了下来",
	&"scientist": "科学家打开了虫洞：以阶段 5 冲进去，掉头撞碎它",
}
const TOAST_TIME := 2.5

var _toast: Label
var _toast_left := 0.0

@onready var _debug: Label = $Debug

func _ready() -> void:
	_debug.position = Vector2(16, 12)
	_toast = Menu.label("", 26, Color("ffe9b0"))
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# 放在屏幕最上面：赛道比屏幕矮，这里一般是赛道外的暗处。
	_toast.offset_top = 36.0
	_toast.modulate.a = 0.0
	add_child(_toast)
	Game.help_triggered.connect(_on_help_triggered)

func _on_help_triggered(role: StringName) -> void:
	if HELP_TEXT.has(role):
		_toast.text = HELP_TEXT[role]
		_toast_left = TOAST_TIME

func _process(delta: float) -> void:
	_toast_left = maxf(_toast_left - delta, 0.0)
	_toast.modulate.a = clampf(_toast_left / 0.5, 0.0, 1.0)
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
