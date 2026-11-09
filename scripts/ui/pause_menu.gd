extends CanvasLayer
## 暂停菜单（Esc）：继续 / 回到检查点 / 回到标题。挂在 Game 下面，暂停时照样处理输入。

var _first: Button

func _ready() -> void:
	layer = 90
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := Menu.centered_column(self)
	_first = Menu.button("继续", Game.toggle_pause)
	box.add_child(_first)
	box.add_child(Menu.button("回到检查点", Game.respawn))
	box.add_child(_settings_button())
	box.add_child(Menu.button("回到标题", Game.to_title))

func _settings_button() -> Button:
	return Menu.button("设置", func() -> void:
		var panel := (load("res://scenes/ui/settings.tscn") as PackedScene).instantiate()
		add_child(panel)
		panel.closed.connect(func() -> void: if _first != null: _first.grab_focus()))

func focus_first() -> void:
	_first.grab_focus()
