extends Node
## 真结局连环画（ending_comic）：每页先只露第一格，3 秒多一格；点一下立刻多一格并重置计时；
## 四格齐了再点翻页；三页之后是 CG，CG 先播运镜（拉近→左下→中→中上→中→拉远），
## 运镜途中点一下跳到结尾，运镜结束以后再点回标题。
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

	# CG 运镜：0.8 秒拉近到左下，之后一路推；7.6 秒拉回正常大小。
	_check("CG 一开始是正常大小", comic.cg_zoom() < 1.2, "%.2f" % comic.cg_zoom())
	_click()
	await _frames(2)
	_check("CG 刚出来那一下点不掉（防误触）", not comic.finished() and comic.cg_time() < 0.2, "t=%.2f" % comic.cg_time())
	await _frames(34)
	_check("0.6 秒：已经在拉近", comic.cg_zoom() > 1.25, "%.2f" % comic.cg_zoom())
	var early := EndingComic.camera_at(0.8)
	_check("0.8 秒：左下特写 2.2 倍", is_equal_approx(early[1], 2.2) and (early[0] as Vector2).x < 0.35, "%s" % [early])
	var up := EndingComic.camera_at(4.0)
	_check("4 秒：中上（灯泡）", is_equal_approx(up[1], 2.2) and (up[0] as Vector2).y < 0.35, "%s" % [up])
	var normal := EndingComic.camera_at(EndingComic.camera_length())
	_check("结尾：正常大小、正中", is_equal_approx(normal[1], 1.0) and (normal[0] as Vector2) == Vector2(0.5, 0.5), "%s" % [normal])

	_click()
	await _frames(2)
	_check("运镜途中点一下：跳到结尾，还不回标题",
		not comic.finished() and is_equal_approx(comic.cg_time(), EndingComic.camera_length()) and is_equal_approx(comic.cg_zoom(), 1.0),
		"t=%.2f zoom=%.2f" % [comic.cg_time(), comic.cg_zoom()])
	_click()
	await _frames(2)
	_check("再看一下点：回标题", comic.finished())

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
