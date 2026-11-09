extends CanvasLayer
## 设置面板：全图形，没有文字（和游戏"画面上不写字"的规矩一致）。
## 局内只给两条音量；难度只在局外显示（改难度要重进本章才生效）。
##   音效 [◀] ▮▮▮▮▮▯▯▯▯▯ [▶]
##   音乐 [◀] ▮▮▮▮▮▮▮▯▯▯ [▶]
##   难度  ★   ◐   ●      （★ 微光 / ◐ 长夜 / ● 永夜）
##   关闭  ✕

signal closed

const STEP := 0.1
const PIPS := 10

var _sfx_pips: Control
var _music_pips: Control
var _diff_picks: Array[Control] = []
var _was_paused := false

static func in_game() -> bool:
	return Game.flow == Game.Flow.PLAYING or Game.flow == Game.Flow.CHASE or Game.flow == Game.Flow.PAUSED

func _ready() -> void:
	layer = 95
	_was_paused = get_tree().paused
	if in_game():
		get_tree().paused = true

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := Menu.centered_column(self, 22)
	box.add_child(_star_badge())

	_sfx_pips = _volume_row(box, Icon.Kind.SFX, "sfx")
	_music_pips = _volume_row(box, Icon.Kind.MUSIC, "music")

	var diff := HBoxContainer.new()
	diff.alignment = BoxContainer.ALIGNMENT_CENTER
	diff.add_theme_constant_override("separation", 26)
	box.add_child(diff)
	diff.visible = not in_game()
	var kinds := [Icon.Kind.STAR, Icon.Kind.HALF, Icon.Kind.ECLIPSE]
	for i in 3:
		var pick := Icon.new(kinds[i])
		pick.custom_minimum_size = Vector2(58, 58)
		pick.pressed.connect(func() -> void: _pick_difficulty(i))
		diff.add_child(pick)
		_diff_picks.append(pick)

	var close := Icon.new(Icon.Kind.CLOSE)
	close.custom_minimum_size = Vector2(54, 54)
	close.pressed.connect(_close)
	box.add_child(close)
	_refresh()

func _star_badge() -> Control:
	var badge := Icon.new(Icon.Kind.STAR)
	badge.custom_minimum_size = Vector2(46, 46)
	return badge

func _volume_row(box: VBoxContainer, kind: int, which: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var icon := Icon.new(kind)
	icon.custom_minimum_size = Vector2(46, 46)
	row.add_child(icon)
	var less := Icon.new(Icon.Kind.LEFT)
	less.custom_minimum_size = Vector2(34, 34)
	less.pressed.connect(func() -> void: _bump(which, -1))
	row.add_child(less)
	var pips := Pips.new()
	pips.custom_minimum_size = Vector2(PIPS * 16.0, 26)
	row.add_child(pips)
	var more := Icon.new(Icon.Kind.RIGHT)
	more.custom_minimum_size = Vector2(34, 34)
	more.pressed.connect(func() -> void: _bump(which, 1))
	row.add_child(more)
	return pips

func _bump(which: String, dir: int) -> void:
	if which == "sfx":
		Save.sfx_volume = clampf(snappedf(Save.sfx_volume + dir * STEP, STEP), 0.0, 1.0)
	else:
		Save.music_volume = clampf(snappedf(Save.music_volume + dir * STEP, STEP), 0.0, 1.0)
	Audio.apply_volume()
	Audio.play(&"warp", 1.35)
	_refresh()

func _pick_difficulty(index: int) -> void:
	Save.difficulty = index
	Game.apply_difficulty()
	Audio.play(&"warp", 1.2)
	_refresh()

func _refresh() -> void:
	if _sfx_pips != null:
		_sfx_pips.value = Save.sfx_volume
		_sfx_pips.queue_redraw()
	if _music_pips != null:
		_music_pips.value = Save.music_volume
		_music_pips.queue_redraw()
	for i in _diff_picks.size():
		_diff_picks[i].selected = i == Save.difficulty
		_diff_picks[i].queue_redraw()

func _close() -> void:
	if in_game():
		get_tree().paused = _was_paused
	Save.write()
	closed.emit()
	queue_free()

# ---------------- 画图标的小控件 ----------------

class Icon:
	extends Control

	enum Kind { SFX, MUSIC, LEFT, RIGHT, CLOSE, STAR, HALF, ECLIPSE }

	signal pressed

	var kind := Kind.SFX
	var selected := false
	var _hover := false

	func _init(k: int = Kind.SFX) -> void:
		kind = k
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_entered.connect(func() -> void: _hover = true; queue_redraw())
		mouse_exited.connect(func() -> void: _hover = false; queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			pressed.emit()

	func _draw() -> void:
		var hot := Color("ffd75a")
		var idle := Color("b9c8ff")
		var c := hot if (_hover or selected) else idle
		var m := size * 0.5
		var r := minf(size.x, size.y) * 0.36
		match kind:
			Kind.SFX:
				# 喇叭 + 两道声波
				draw_colored_polygon(PackedVector2Array([
					m + Vector2(-r, -r * 0.35), m + Vector2(-r * 0.45, -r * 0.35),
					m + Vector2(r * 0.15, -r), m + Vector2(r * 0.15, r),
					m + Vector2(-r * 0.45, r * 0.35), m + Vector2(-r, r * 0.35)]), c)
				draw_arc(m + Vector2(r * 0.2, 0), r * 0.55, -0.9, 0.9, 16, c, 2.0, true)
				draw_arc(m + Vector2(r * 0.2, 0), r * 0.95, -0.9, 0.9, 20, Color(c, 0.7), 2.0, true)
			Kind.MUSIC:
				# 八分音符
				draw_circle(m + Vector2(-r * 0.25, r * 0.55), r * 0.34, c)
				draw_line(m + Vector2(r * 0.05, r * 0.55), m + Vector2(r * 0.05, -r * 0.85), c, 3.0)
				draw_line(m + Vector2(r * 0.05, -r * 0.85), m + Vector2(r * 0.75, -r * 0.55), c, 3.0)
			Kind.LEFT:
				draw_colored_polygon(PackedVector2Array([
					m + Vector2(-r * 0.6, 0), m + Vector2(r * 0.5, -r * 0.8), m + Vector2(r * 0.5, r * 0.8)]), c)
			Kind.RIGHT:
				draw_colored_polygon(PackedVector2Array([
					m + Vector2(r * 0.6, 0), m + Vector2(-r * 0.5, -r * 0.8), m + Vector2(-r * 0.5, r * 0.8)]), c)
			Kind.CLOSE:
				draw_line(m + Vector2(-r, -r), m + Vector2(r, r), c, 4.0, true)
				draw_line(m + Vector2(r, -r), m + Vector2(-r, r), c, 4.0, true)
			Kind.STAR:
				var pts := PackedVector2Array()
				for i in 8:
					var a := TAU * float(i) / 8.0 - PI / 2.0
					var rr := r if i % 2 == 0 else r * 0.26
					pts.append(m + Vector2.from_angle(a) * rr)
				draw_colored_polygon(pts, c)
			Kind.HALF:
				draw_circle(m, r, Color(c, 0.35))
				draw_colored_polygon(PackedVector2Array(_half_arc(m, r)), c)
				draw_arc(m, r, 0.0, TAU, 28, c, 1.5, true)
			Kind.ECLIPSE:
				draw_circle(m, r, Color(0.02, 0.01, 0.04, 0.95))
				draw_arc(m, r, 0.0, TAU, 28, c, 3.0, true)
				draw_arc(m, r * 0.72, 0.0, TAU, 24, Color(c, 0.5), 1.5, true)

	func _half_arc(m: Vector2, r: float) -> Array[Vector2]:
		var out: Array[Vector2] = []
		out.append(m)
		for i in 17:
			var a := -PI * 0.5 + PI * float(i) / 16.0
			out.append(m + Vector2.from_angle(a) * r)
		return out

class Pips:
	extends Control

	var value := 1.0

	func _draw() -> void:
		var n := 10
		var w := size.x / float(n * 2 - 1)
		for i in n:
			var x := i * w * 2.0
			var filled := float(i) < value * n - 0.05
			var col := Color("ffd75a") if filled else Color("b9c8ff", 0.28)
			draw_rect(Rect2(x, 0.0, w, size.y), col)
