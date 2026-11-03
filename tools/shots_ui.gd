extends Node
## 截图用：标题、暂停菜单、结局各录一帧。存档写到临时文件，不动玩家的存档。
##   godot --path . --rendering-driver opengl3 --write-movie /tmp/shots/f.png --fixed-fps 30 res://tools/shots_ui.tscn
## 每张的帧编号会打印出来。录完自动退出。

const PATH := "user://shots_ui_save.json"

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())

class Runner extends Node:
	func _ready() -> void:
		Save.path = PATH
		Game.debug_panel = false
		get_tree().change_scene_to_file(Game.TITLE_SCENE)
		await _frames(40)
		_shot("标题")
		Game.start_new()
		while Game.flow != Game.Flow.PLAYING:
			await get_tree().process_frame
		await _frames(30)
		Game.toggle_pause()
		await _frames(10)
		_shot("暂停")
		Game.toggle_pause()
		for role in [&"watchman", &"gardener", &"painter", &"guide", &"miner", &"clockmaker", &"musician", &"listener"]:
			Save.rescued["shots/%s" % role] = role
		Game.call(&"_show_ending", &"main")
		await _frames(150)
		_shot("结局")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		get_tree().quit()

	func _shot(name: String) -> void:
		print("SHOT %s %d" % [name, Engine.get_frames_drawn() - 1])

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame
