extends Node
## 截图用：真结局连环画的几个状态（第一页第一格 / 第二格 / 四格齐 / 第二页第一格 / CG 运镜四段）。
##   godot --path . --rendering-driver opengl3 --fixed-fps 30 \
##     --write-movie .tmp_build/shots/comic/f.png res://tools/shots_ending_comic.tscn
## 打印的帧号就是对应那帧（文件名是 f + 8 位帧号）。

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())

class Runner extends Node:
	const PATH := "user://shots_ending_comic_save.json"

	func _ready() -> void:
		Save.path = PATH
		Save.clear()
		Game.ending = &"hidden"
		get_tree().change_scene_to_file(Game.ENDING_COMIC_SCENE)
		await _frames(10)
		var comic := get_tree().current_scene as EndingComic
		await _shot(comic, "page1_panel1")
		click(comic)
		await _shot(comic, "page1_panel2")
		click(comic)
		await _frames(2)
		click(comic)
		await _shot(comic, "page1_panel4")
		click(comic)
		await _shot(comic, "page2_panel1")
		for i in 3:
			click(comic)
			await _frames(2)
		click(comic)
		await _shot(comic, "page3_panel1")
		for i in 3:
			click(comic)
			await _frames(2)
		click(comic)
		await _frames(24)
		await _shot(comic, "cg_left")
		await _frames(48)
		await _shot(comic, "cg_mid")
		await _frames(48)
		await _shot(comic, "cg_up")
		await _frames(110)
		await _shot(comic, "cg_full")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		get_tree().quit()

	func click(_comic: EndingComic) -> void:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		get_tree().root.push_input(down)
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		get_tree().root.push_input(up)

	func _shot(comic: EndingComic, name: String) -> void:
		await _frames(2)
		print("SHOT %s %d  page=%d shown=%d t=%.2f zoom=%.2f" % [name, Engine.get_frames_drawn() - 1,
			comic.progress().x, comic.progress().y, comic.cg_time(), comic.cg_zoom()])

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame
