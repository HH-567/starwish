class_name Menu
## 标题、暂停、结局共用的按钮样式：没有底框，平时淡蓝，鼠标悬停或键盘选中时暖黄。

const IDLE := Color("b9c8ff")
const HOT := Color("ffd75a")

static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", IDLE)
	b.add_theme_color_override("font_hover_color", HOT)
	b.add_theme_color_override("font_focus_color", HOT)
	b.add_theme_color_override("font_pressed_color", HOT.lightened(0.4))
	b.add_theme_color_override("font_disabled_color", Color(IDLE, 0.35))
	# 不画默认的焦点框，选中靠颜色表示；鼠标移上去就把焦点给它，键鼠只有一个高亮。
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_entered.connect(b.grab_focus)
	b.pressed.connect(on_pressed)
	return b

static func label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l

## 铺满屏幕、内容居中的竖排容器。
static func centered_column(parent: Node, separation := 14) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	center.add_child(box)
	return box
