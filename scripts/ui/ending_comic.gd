class_name EndingComic
extends Control
## 真结局（隐藏结局）：三页四格连环画，一格一格放出来，最后一张 CG。
## 进入条件：12 个人全救（科学家才开虫洞）+ 冲进虫洞掉头撞碎噬光者。
##
## 播放规则（游戏设计定的）：
##   每页一开始只露第一格，其余纯白；每 PAGE_WAIT 秒自动多放一格；
##   点一下鼠标（触屏、空格/回车也算）立刻放下一格，并把计时重置；
##   四格都出来了再点，翻到下一页；第三页之后是 CG；
##   CG 上点一下回标题，Esc 随时回标题。
##
## 漫画是一张白底四格图，四个画面的位置由 tools/comic_panels.py 量出来（见下面的 PANELS）。
## 没轮到的格子：用它的多边形（比实际画面大一圈）涂白——多出来的那圈落在格子的白缝里，
## 所以看到的边是干净的白，不会在画面上切出一条锯齿。
## 缺图时 Game.ending_scene 会退回老的两句台词结局页（ending.tscn）。

const IMAGES := [
	"res://assets/art/cg/1.png",
	"res://assets/art/cg/2.png",
	"res://assets/art/cg/3.png",
]
const CG_IMAGE := "res://assets/art/cg/CG.png"
const PANELS_PER_PAGE := 4
## 自动放下一格要等多久，秒。
const PAGE_WAIT := 3.0
## 涂白用的多边形再往外盖多少像素（落在白缝里就看不见）。
const MASK_GROW := 3.5
## CG 刚出来时先锁一下输入，免得翻页那一下双击顺手把 CG 也点掉。
const CG_LOCK := 0.5
const PAPER := Color.WHITE

## 每页四格画面的多边形（0..1 比例，阅读顺序：左上、右上、左下、右下）。
## 由 tools/comic_panels.py 从白底图上量出来；换图后重跑那个脚本，把这一段整段换掉。
const PANELS := [
	[
		[Vector2(0.0347, 0.0486), Vector2(0.3586, 0.0486), Vector2(0.3596, 0.0503), Vector2(0.3913, 0.1363), Vector2(0.5100, 0.4705), Vector2(0.5046, 0.4731), Vector2(0.0337, 0.6137), Vector2(0.0332, 0.6120)],
		[Vector2(0.3723, 0.0486), Vector2(0.9668, 0.0495), Vector2(0.9668, 0.6163), Vector2(0.9658, 0.6181), Vector2(0.9634, 0.6181), Vector2(0.9428, 0.6111), Vector2(0.5227, 0.4661), Vector2(0.4949, 0.3932)],
		[Vector2(0.0342, 0.6337), Vector2(0.0357, 0.6328), Vector2(0.0684, 0.6224), Vector2(0.5276, 0.4844), Vector2(0.5789, 0.5052), Vector2(0.5784, 0.5069), Vector2(0.5672, 0.5408), Vector2(0.4226, 0.9531), Vector2(0.0337, 0.9531), Vector2(0.0332, 0.9505)],
		[Vector2(0.4358, 0.9488), Vector2(0.4402, 0.9332), Vector2(0.4841, 0.8056), Vector2(0.5901, 0.5069), Vector2(0.5955, 0.5078), Vector2(0.9668, 0.6380), Vector2(0.9668, 0.9514), Vector2(0.9658, 0.9531), Vector2(0.4362, 0.9531)],
	],
	[
		[Vector2(0.0156, 0.2812), Vector2(0.0171, 0.0295), Vector2(0.4231, 0.0295), Vector2(0.4240, 0.0312), Vector2(0.4377, 0.1094), Vector2(0.4885, 0.4366), Vector2(0.4856, 0.4375), Vector2(0.0371, 0.5451), Vector2(0.0166, 0.5469)],
		[Vector2(0.4323, 0.0304), Vector2(0.4333, 0.0295), Vector2(0.9819, 0.0295), Vector2(0.9829, 0.0312), Vector2(0.9839, 0.0495), Vector2(0.9839, 0.4401), Vector2(0.9819, 0.4436), Vector2(0.9800, 0.4444), Vector2(0.9384, 0.4583), Vector2(0.5208, 0.5694), Vector2(0.5198, 0.5677), Vector2(0.5178, 0.5616), Vector2(0.4939, 0.4418), Vector2(0.4323, 0.0391)],
		[Vector2(0.0166, 0.5651), Vector2(0.0181, 0.5642), Vector2(0.4934, 0.4540), Vector2(0.4973, 0.4757), Vector2(0.5525, 0.8021), Vector2(0.5769, 0.9731), Vector2(0.0166, 0.9731), Vector2(0.0161, 0.9679)],
		[Vector2(0.5232, 0.5859), Vector2(0.5252, 0.5851), Vector2(0.9614, 0.4653), Vector2(0.9829, 0.4635), Vector2(0.9844, 0.4913), Vector2(0.9819, 0.9740), Vector2(0.5843, 0.9696), Vector2(0.5804, 0.9479), Vector2(0.5559, 0.8021), Vector2(0.5252, 0.6111)],
	],
	[
		[Vector2(0.0225, 0.0842), Vector2(0.0479, 0.0417), Vector2(0.5403, 0.0417), Vector2(0.5418, 0.0443), Vector2(0.5413, 0.0477), Vector2(0.5320, 0.0955), Vector2(0.4411, 0.5269), Vector2(0.4265, 0.5269), Vector2(0.1764, 0.5035), Vector2(0.0225, 0.4844)],
		[Vector2(0.4529, 0.5208), Vector2(0.4568, 0.4965), Vector2(0.5520, 0.0417), Vector2(0.9521, 0.0417), Vector2(0.9780, 0.0868), Vector2(0.9785, 0.1102), Vector2(0.9756, 0.3776), Vector2(0.9052, 0.3993), Vector2(0.4529, 0.5243)],
		[Vector2(0.0234, 0.5052), Vector2(0.0303, 0.5052), Vector2(0.3781, 0.5365), Vector2(0.4431, 0.5469), Vector2(0.4441, 0.5503), Vector2(0.4538, 0.5903), Vector2(0.5281, 0.9583), Vector2(0.5271, 0.9592), Vector2(0.0479, 0.9592), Vector2(0.0225, 0.9149), Vector2(0.0220, 0.5122)],
		[Vector2(0.4538, 0.5451), Vector2(0.4573, 0.5434), Vector2(0.6468, 0.4878), Vector2(0.9145, 0.4115), Vector2(0.9761, 0.3967), Vector2(0.9770, 0.3984), Vector2(0.9780, 0.4271), Vector2(0.9790, 0.6953), Vector2(0.9770, 0.9149), Vector2(0.9619, 0.9436), Vector2(0.9516, 0.9592), Vector2(0.5393, 0.9575), Vector2(0.5374, 0.9531), Vector2(0.5261, 0.9019), Vector2(0.4587, 0.5799), Vector2(0.4533, 0.5486)],
	],
]

## 第几页：0..IMAGES.size()-1 是漫画，IMAGES.size() 是 CG。
var _page := 0
## 这一页已经露出几格（1..4）。
var _shown := 1
var _wait := 0.0
var _cg_lock := 0.0
var _leaving := false
var _pages: Array[Texture2D] = []
var _cg: Texture2D

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 自己不挡鼠标：整页只有这一块 Control，不设 IGNORE 的话点击会被 GUI 吃掉，
	# _unhandled_input 就收不到"点一下翻一格"。
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	Audio.set_ducked(false)
	Audio.play_bgm(&"ending_hidden")
	# 四张大图一起读进来：读盘只在进结局那一下，翻页时不会卡。
	for path in IMAGES:
		_pages.append(load(path) as Texture2D)
	_cg = load(CG_IMAGE) as Texture2D
	queue_redraw()

## 四张图都在才播连环画；缺一张就退回老结局页。
static func available() -> bool:
	for path in IMAGES + [CG_IMAGE]:
		if not ResourceLoader.exists(path):
			return false
	return true

## 现在在第几页、露了几格（测试和截图用）。
func progress() -> Vector2i:
	return Vector2i(_page, _shown)

## 是不是已经点完回标题了（测试用）。
func finished() -> bool:
	return _leaving

func _process(delta: float) -> void:
	if _leaving:
		return
	if _page >= IMAGES.size():
		_cg_lock = maxf(_cg_lock - delta, 0.0)
		return
	_wait += delta
	if _shown < PANELS_PER_PAGE and _wait >= PAGE_WAIT:
		_reveal()

func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed("pause"):
		_leave()
		get_viewport().set_input_as_handled()
		return
	var tap := false
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		tap = click.button_index == MOUSE_BUTTON_LEFT and click.is_pressed()
	elif event is InputEventScreenTouch:
		tap = (event as InputEventScreenTouch).is_pressed()
	elif event.is_action_pressed("ui_accept"):
		tap = true
	if tap:
		_advance()
		get_viewport().set_input_as_handled()

## 下一步：放一格，或者（四格都齐了）翻页，或者（在看 CG）回标题。
func _advance() -> void:
	if _page >= IMAGES.size():
		if _cg_lock <= 0.0:
			_leave()
		return
	if _shown < PANELS_PER_PAGE:
		_reveal()
		return
	_turn_page()

func _reveal() -> void:
	_shown += 1
	_wait = 0.0
	Audio.play(&"ui")
	queue_redraw()

func _turn_page() -> void:
	_page += 1
	_shown = 1
	_wait = 0.0
	if _page >= IMAGES.size():
		_cg_lock = CG_LOCK
		Audio.play(&"ending")
	else:
		Audio.play(&"clear")
	queue_redraw()

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	Game.to_title()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	if _page >= IMAGES.size():
		if _cg != null:
			draw_texture_rect(_cg, _fit(_cg), false)
		return
	if _page >= _pages.size() or _pages[_page] == null:
		return
	var page := _fit(_pages[_page])
	draw_texture_rect(_pages[_page], page, false)
	# 还没轮到的格子涂白：多边形本身再把边加粗一圈，边就落进白缝里了。
	for i in range(_shown, PANELS_PER_PAGE):
		var pts := _panel_points(_page, i, page)
		if pts.size() < 3:
			continue
		draw_colored_polygon(pts, PAPER)
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, PAPER, MASK_GROW * 2.0)

## 整页（或 CG）按原比例放进屏幕，居中。
func _fit(tex: Texture2D) -> Rect2:
	var src := Vector2(tex.get_size())
	if src.x <= 0.0 or src.y <= 0.0:
		return Rect2(Vector2.ZERO, size)
	var k := minf(size.x / src.x, size.y / src.y)
	var drawn := src * k
	return Rect2((size - drawn) * 0.5, drawn)

## 第 page 页第 i 格在当前屏幕上的多边形（PANELS 里是 0..1 比例）。
func _panel_points(page: int, i: int, page_rect: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if page < 0 or page >= PANELS.size() or i < 0 or i >= PANELS[page].size():
		return pts
	for p: Vector2 in PANELS[page][i]:
		pts.append(page_rect.position + Vector2(p.x, p.y) * page_rect.size)
	return pts
