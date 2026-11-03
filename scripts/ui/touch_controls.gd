extends Control
## 触屏控件（docs/level-data-format.md 第 9 节）：左半屏拖动是移动，右半屏拖动是瞄准，
## 右下角"光"按钮切换散射/聚光，右上角暂停。
## 只在 Controls.touch 为真时出现，键鼠时不挡鼠标。
## 触摸事件自带 index，所以两个大拇指可以同时推左右摇杆。

const RADIUS := 88.0
const DEADZONE := 6.0
const RING := Color(0.72, 0.82, 1.0, 0.22)
const KNOB := Color(0.85, 0.92, 1.0, 0.55)

## 一根摇杆：动的是哪根手指（-1 = 没动）、原点、现在的位置。
class Stick:
	extends RefCounted

	var index := -1
	var origin := Vector2.ZERO
	var pos := Vector2.ZERO

	func begin(at_index: int, at: Vector2) -> void:
		index = at_index
		origin = at
		pos = at

	func end() -> void:
		index = -1
		origin = Vector2.ZERO
		pos = Vector2.ZERO

	func vector() -> Vector2:
		if index < 0:
			return Vector2.ZERO
		var offset := pos - origin
		if offset.length() < DEADZONE:
			return Vector2.ZERO
		return (offset / RADIUS).limit_length(1.0)

var _left := Stick.new()
var _right := Stick.new()
var _light: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 自己不接收鼠标/触摸：摇杆在 _input 里统一处理，按钮是子节点、各自收自己的。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_light = _icon_button("LightButton", Vector2(88, 88), _draw_sun)
	_light.pressed.connect(func() -> void: Controls.request_mode_toggle())
	var pause := _icon_button("PauseButton", Vector2(64, 64), _draw_bars)
	pause.pressed.connect(func() -> void: Game.toggle_pause())
	visible = Controls.touch

## 按钮里不写字：图标是画上去的（太阳 = 换光，三道横线 = 暂停）。
func _icon_button(node_name: String, box: Vector2, painter: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = box
	add_child(button)
	var icon := Control.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.draw.connect(func() -> void: painter.call(icon, icon.size))
	button.add_child(icon)
	return button

func _draw_sun(item: CanvasItem, box: Vector2) -> void:
	var c := Color(1.0, 0.9, 0.5, 0.9)
	var center := box * 0.5
	var r := minf(box.x, box.y) * 0.18
	item.draw_circle(center, r, c)
	for k in 8:
		var d := Vector2.from_angle(TAU * k / 8.0)
		item.draw_line(center + d * r * 1.7, center + d * r * 2.9, c, 3.0)

func _draw_bars(item: CanvasItem, box: Vector2) -> void:
	var c := Color(0.85, 0.92, 1.0, 0.85)
	var center := box * 0.5
	for k in 3:
		var y := center.y + (k - 1) * 9.0
		item.draw_line(Vector2(center.x - 14.0, y), Vector2(center.x + 14.0, y), c, 3.5)

func _process(_delta: float) -> void:
	# 暂停时不显示：暂停菜单的按钮要能点（触屏也是靠模拟鼠标点按钮的）。
	var want := Controls.touch and not get_tree().paused
	if visible != want:
		visible = want
		if not want:
			_reset()
	if not visible:
		return
	# 用视口尺寸：控件自己的 size 在布局之前可能是 0。
	var view := get_viewport_rect().size
	_light.position = view - Vector2(128.0, 128.0)
	var pause := get_node_or_null(^"PauseButton") as Button
	if pause != null:
		# 放低一点，别压住右上角的速度档位点。
		pause.position = Vector2(view.x - 88.0, 96.0)
	queue_redraw()

## 摇杆统一在这里收：触摸带 index，两根手指能同时推左右；桌面上用鼠标也能试。
## 点在两个按钮上就交给按钮自己处理。
func _input(event: InputEvent) -> void:
	if not Controls.touch:
		return
	var half := get_viewport_rect().size.x * 0.5
	# 注意：match 里写类名不会当类型判断用，必须用 is。
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if _on_button(touch.position):
			return
		if touch.pressed:
			_begin("left" if touch.position.x < half else "right", touch.index, touch.position)
		else:
			_end(touch.index)
		accept_event()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if _on_button(drag.position):
			return
		_move(drag.index, drag.position)
		accept_event()
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index != MOUSE_BUTTON_LEFT or _on_button(button.position):
			return
		if button.pressed:
			_begin("left" if button.position.x < half else "right", 0, button.position)
		else:
			_end(0)
		accept_event()
	elif event is InputEventMouseMotion:
		if not _on_button(event.position):
			_move(0, event.position)

## 这个点是不是落在"光"或暂停按钮上。
func _on_button(at: Vector2) -> bool:
	var pause := get_node_or_null(^"PauseButton") as Button
	for button: Button in [_light, pause]:
		if button != null and button.visible and button.get_global_rect().has_point(at):
			return true
	return false

func _begin(side: String, index: int, at: Vector2) -> void:
	if side == "left":
		_left.begin(index, at)
	else:
		_right.begin(index, at)
	_apply()

func _move(index: int, at: Vector2) -> void:
	if _left.index == index:
		_left.pos = at
		_apply()
	elif _right.index == index:
		_right.pos = at
		_apply()

func _end(index: int) -> void:
	if _left.index == index:
		_left.end()
	if _right.index == index:
		_right.end()
	_apply()

## 松开所有摇杆、清掉输出（隐藏或暂停时用，免得小星一直往一个方向跑）。
func _reset() -> void:
	_left.end()
	_right.end()
	Controls.move = Vector2.ZERO
	Controls.aim = Vector2.ZERO
	queue_redraw()

## 把两根摇杆的位置换算成 -1..1 的方向，写进 Controls。
func _apply() -> void:
	Controls.move = _left.vector()
	Controls.aim = _right.vector()
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	for stick: Stick in [_left, _right]:
		if stick.index < 0:
			continue
		var offset: Vector2 = (stick.pos - stick.origin).limit_length(RADIUS)
		draw_arc(stick.origin, RADIUS, 0.0, TAU, 48, RING, 3.0, true)
		draw_circle(stick.origin + offset, 26.0, KNOB)
