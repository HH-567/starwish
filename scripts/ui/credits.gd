extends CanvasLayer
## 制作名单：一张纸，点一下 / Esc 就回去。
## 这是全游戏唯一"允许写字"的地方（名单本身就是文字），其余界面仍然是图形。

signal closed

const ENTRIES := [
	["制作人", ["伍陸柒柒"]],
	["策划", ["伍陸柒柒", "cat"]],
	["程序", ["5677"]],
	["美术", ["贰叁是柿"]],
	["音乐", ["2344"]],
	["音效", ["2344"]],
	["测试", ["伍陸柒柒", "CY", "cat"]],
	["特别感谢", ["星小游"]],
]

func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	for old in get_tree().get_nodes_in_group(&"credits_panel"):
		old.queue_free()
	add_to_group(&"credits_panel")

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.035, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	box.add_child(_gap(36))
	box.add_child(Menu.label("《星愿：撞破长夜》", 34, Title.STAR))
	box.add_child(_gap(22))
	for entry: Array in ENTRIES:
		box.add_child(Menu.label(String(entry[0]), 22, Color(Title.SUB, 0.85)))
		for who: String in entry[1]:
			box.add_child(Menu.label(who, 19, Color(Title.SUB, 0.62)))
		box.add_child(_gap(14))
	box.add_child(_gap(10))
	box.add_child(Menu.label("感谢所有参与和支持本作的人~", 18, Color(Title.STAR, 0.55)))
	box.add_child(_gap(30))

func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

func _on_dim_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_close()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()
