extends Node
## 截图用：终章（全救了）的几个镜头，最后是隐藏结局。存档写到临时文件，不动玩家的存档。
##   godot --path . --rendering-driver opengl3 --write-movie /tmp/shots/f.png --fixed-fps 30 res://tools/shots_finale.tscn
## 每个镜头的帧编号会打印出来。录完自动退出。

const PATH := "user://shots_finale_save.json"
## 截图用的章节表：拿两张测试关的赛道来拍多段拼接（和 tests/test_finale.gd 一样）。
## 正式章节的赛道也能拍，但那要另写一套格子坐标。
const TEST_CHAPTERS := [
	[&"test_light", "res://scenes/levels/test_light.tscn"],
	[&"test_feel", "res://scenes/levels/test_feel.tscn"],
]
## 镜头：名字、段（Intro、Outro 或章节 id）、列、行、噬光者摆在小星右边多远（0 = 不动它）、先停多少帧。
const POSES := [
	["守夜人和路灯", "test_light", 121, 8, 0.0, 40],
	["医生和钟表匠", "test_light", 111, 8, 0.0, 10],
	["画家的光门", "test_light", 103, 8, 0.0, 10],
	["园丁的花", "test_light", 70, 8, 0.0, 10],
	["乐手和听众", "test_light", 61, 6, 0.0, 10],
	["矿工的隧道", "test_light", 49, 8, 0.0, 10],
	["噬光者追上来（有盾）", "test_feel", 70, 8, 220.0, 10],
	["噬光者在屏幕外", "test_feel", 40, 8, 1000.0, 10],
	["科学家的虫洞", "Outro", 26, 10, 0.0, 10],
	["逃离点", "Outro", 8, 8, 0.0, 10],
]

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())

class Runner extends Node:
	func _ready() -> void:
		Save.path = PATH
		Game.chapters = TEST_CHAPTERS
		Game.debug_panel = false
		Game.debug_no_decay = true
		Save.clear()
		for chapter: Array in Game.chapters:
			var root := (load(chapter[1]) as PackedScene).instantiate()
			for npc: Npc in root.find_children("*", "Npc", true, false):
				Save.rescued[Save.id_of(npc)] = StringName(npc.role)
			root.free()
		get_tree().change_scene_to_file(Game.FINALE_SCENE)
		await _frames(2)
		var finale := get_tree().current_scene as Finale
		var player := finale.player
		var boss := finale.boss
		player.aim_from_mouse = false
		await _frames(30)
		_shot("开头：噬光者登场")
		while boss.state != Boss.State.CHASE:
			await get_tree().process_frame
		# 镜头之间噬光者不动，按需要摆。
		boss.set_physics_process(false)
		boss.global_position = Vector2(100000, 0)
		var cam := player.get_node(^"Camera") as Camera2D
		for pose: Array in POSES:
			player.global_position = _cell(finale, pose[1], pose[2], pose[3])
			player.velocity = Vector2.ZERO
			if pose[4] > 0.0:
				boss.global_position = player.global_position + Vector2.RIGHT * pose[4]
				boss.queue_redraw()
			cam.reset_smoothing()
			await _frames(pose[5])
			_shot(pose[0])
			if pose[4] > 0.0:
				boss.global_position = Vector2(100000, 0)
		Game.call(&"_show_ending", &"hidden")
		await _frames(170)
		_shot("隐藏结局")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		get_tree().quit()

	## 某一段地图里一格的中心（一格 32 px）。
	func _cell(finale: Finale, section: String, col: int, row: int) -> Vector2:
		var area: Node2D
		if section == "Intro" or section == "Outro":
			area = finale.get_node(section) as Node2D
		else:
			for child in finale.get_children():
				if child is Chapter and String(child.chapter_id) == section:
					area = child.get_node(^"ChaseLane") as Node2D
		return area.global_position + Vector2((col + 0.5) * 32.0, (row + 0.5) * 32.0)

	func _shot(name: String) -> void:
		print("SHOT %s %d" % [name, Engine.get_frames_drawn() - 1])

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame
