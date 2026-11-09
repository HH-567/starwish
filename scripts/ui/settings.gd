extends CanvasLayer
## 设置面板：音效 / 音乐音量，局外还能调难度。
## 局内（关卡里）只给音量；难度只在标题界面能改——难度会改关卡内容，中途改会让人莫名其妙。
##   docs/settings.md

signal closed

const STEP := 0.1
const DIFFICULTY_NAMES := ["微光级", "长夜级", "永夜级"]
const DIFFICULTY_TIPS := [
	"现在这样：补给管够，救人也回光。",
	"补给只剩敌人身后的那几颗；救人不再回光。",
	"光掉得更快，敌人更多。",
]

var _sfx_value: Label
var _music_value: Label
var _diff_value: Label
var _diff_tip: Label
var _diff_row: HBoxContainer
var _first: Button

static func in_game() -> bool:
	return Game.flow == Game.Flow.PLAYING or Game.flow == Game.Flow.CHASE or Game.flow == Game.Flow.PAUSED

var _was_paused := false

func _ready() -> void:
	layer = 95
	# 局内打开时暂停游戏，调音量不会边跑边点
	_was_paused = get_tree().paused
	if in_game():
		get_tree().paused = true
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := Menu.centered_column(self, 18)
	box.add_child(Menu.label("设置", 40, Menu.HOT))
	box.add_child(Menu.label("★", 22, Color(Menu.HOT, 0.7)))

	_sfx_value = _row(box, "音效", func(d: int) -> void: _bump("sfx", d))
	_music_value = _row(box, "音乐", func(d: int) -> void: _bump("music", d))

	_diff_row = HBoxContainer.new()
	_diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_diff_row.add_theme_constant_override("separation", 10)
	box.add_child(_diff_row)
	for i in DIFFICULTY_NAMES.size():
		var pick := Menu.button(DIFFICULTY_NAMES[i], func() -> void: _pick_difficulty(i))
		pick.add_theme_font_size_override("font_size", 24)
		_diff_row.add_child(pick)
	_diff_value = Menu.label("", 20, Color(Menu.IDLE, 0.75))
	box.add_child(_diff_value)
	_diff_tip = Menu.label("", 19, Color(Menu.IDLE, 0.55))
	box.add_child(_diff_tip)
	_diff_row.visible = not in_game()

	_first = Menu.button("关 闭", _close)
	box.add_child(_first)
	_refresh()
	if _first != null:
		_first.grab_focus()

func _row(box: VBoxContainer, title: String, on_step: Callable) -> Label:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var left := Menu.button("◀", func() -> void: on_step.call(-1))
	var value := Menu.label("", 24, Menu.IDLE)
	value.custom_minimum_size = Vector2(110, 0)
	var right := Menu.button("▶", func() -> void: on_step.call(1))
	var name := Menu.label(title, 24, Menu.IDLE)
	name.custom_minimum_size = Vector2(90, 0)
	row.add_child(name)
	row.add_child(left)
	row.add_child(value)
	row.add_child(right)
	return value

func _bump(which: String, dir: int) -> void:
	match which:
		"sfx":
			Save.sfx_volume = clampf(snappedf(Save.sfx_volume + dir * STEP, STEP), 0.0, 1.0)
		"music":
			Save.music_volume = clampf(snappedf(Save.music_volume + dir * STEP, STEP), 0.0, 1.0)
	Audio.apply_volume()
	_refresh()
	Audio.play(&"warp", 1.35)

func _pick_difficulty(index: int) -> void:
	Save.difficulty = index
	Game.apply_difficulty()
	_refresh()
	Audio.play(&"warp", 1.35)

func _refresh() -> void:
	if _sfx_value != null:
		_sfx_value.text = "%d%%" % roundi(Save.sfx_volume * 100.0)
	if _music_value != null:
		_music_value.text = "%d%%" % roundi(Save.music_volume * 100.0)
	if _diff_value != null:
		_diff_value.text = "难度：%s" % DIFFICULTY_NAMES[Save.difficulty]
	if _diff_tip != null:
		_diff_tip.text = DIFFICULTY_TIPS[Save.difficulty]

func _close() -> void:
	if in_game():
		get_tree().paused = _was_paused
	Save.write()
	closed.emit()
	queue_free()
