extends CanvasLayer
## 暂停菜单（Esc）：继续 / 回到检查点 / 回到标题。挂在 Game 下面，暂停时照样处理输入。

var _first: Button

func _ready() -> void:
	layer = 90
	# 暂停时也要能点
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := Menu.centered_column(self, 16)
	_first = IconButton.make(IconButton.Kind.PLAY, "继续")
	_first.pressed.connect(Game.toggle_pause)
	box.add_child(_first)
	var back := IconButton.make(IconButton.Kind.RESTART, "回到检查点")
	back.pressed.connect(Game.respawn)
	box.add_child(back)
	var gear := IconButton.make(IconButton.Kind.GEAR, "设置")
	gear.pressed.connect(_open_settings)
	box.add_child(gear)
	var home := IconButton.make(IconButton.Kind.HOME, "回到标题")
	home.pressed.connect(Game.to_title)
	box.add_child(home)

func _open_settings() -> void:
	var panel := (load("res://scenes/ui/settings.tscn") as PackedScene).instantiate()
	add_child(panel)
	panel.closed.connect(func() -> void:
		if _first != null:
			_first.grab_focus())

func focus_first() -> void:
	_first.grab_focus()
