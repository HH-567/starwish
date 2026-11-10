extends Node
## 真结局连环画（ending_comic）：每页先只露第一格，3 秒多一格；点一下立刻多一格并重置计时；
## 四格齐了再点翻页；三页之后是 CG，CG 上点一下回标题。
##   godot --headless --path . --fixed-fps 60 res://tests/test_ending_comic.tscn

const PATH := "user://test_ending_comic_save.json"

var _failures := 0

func _ready() -> void:
	Save.path = PATH
	Save.clear()
	Game.ending = &"hidden"
	var comic := (load(Game.ENDING_COMIC_SCENE) as PackedScene).instantiate() as EndingComic
	get_tree().root.add_child.call_deferred(comic)
	await _frames(3)

	_check("第一页只露第一格", comic.progress() == Vector2i(0, 1), _p(comic))
	await _frames(120)
	_check("才两秒：不多放", comic.progress() == Vector2i(0, 1), _p(comic))
	await _frames(70)
	_check("三秒：自动多放一格", comic.progress() == Vector2i(0, 2), _p(comic))

	_click()
	await _frames(2)
	_check("点一下：立刻多放一格", comic.progress() == Vector2i(0, 3), _p(comic))
	await _frames(120)
	_check("点击把三秒计时重置了", comic.progress() == Vector2i(0, 3), _p(comic))

	_click()
	await _frames(2)
	_check("第四格", comic.progress() == Vector2i(0, 4), _p(comic))
	_click()
	await _frames(2)
	_check("四格齐了再点：翻到第二页，又只剩第一格", comic.progress() == Vector2i(1, 1), _p(comic))

	# 一路点到第三页的第四格（每页 3 次点击：2、3、4 格；第 4 次翻页）。
	for i in 7:
		_click()
		await _frames(2)
	_check("点到第三页第四格", comic.progress() == Vector2i(2, 4), _p(comic))
	_click()
	await _frames(2)
	_check("第三页之后是 CG", comic.progress() == Vector2i(3, 1), _p(comic))

	_click()
	await _frames(2)
	_check("CG 刚出来那一下点不掉（防误触）", not comic.finished())
	await _frames(40)
	_click()
	await _frames(2)
	_check("CG 上再点：回标题", comic.finished())

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _click() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	get_tree().root.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	get_tree().root.push_input(up)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _p(comic: EndingComic) -> String:
	return "page=%d shown=%d" % [comic.progress().x, comic.progress().y]

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
