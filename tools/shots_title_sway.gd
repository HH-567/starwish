extends Node
## 截图用：标题页的鼠标视差。依次把鼠标放到中间 / 右边 / 左上角 / 再回中间，各录一帧；
## 最后快速划一下，打印冲量过冲的那一帧（停手以后画面还会再带过去一点）。
##   godot --path . --rendering-driver opengl3 --fixed-fps 30 \
##     --write-movie .tmp_build/shots/sway/f.png res://tools/shots_title_sway.tscn
## 打印的帧号就是对应那帧（文件名是 f + 8 位帧号），sway 是当时的偏移（1 = 屏幕角落）。

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())

class Runner extends Node:
	const PATH := "user://shots_title_sway_save.json"

	func _ready() -> void:
		Save.path = PATH
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		Game.debug_panel = false
		get_tree().change_scene_to_file(Game.TITLE_SCENE)
		await _frames(20)
		var title := get_tree().current_scene as Title
		await _point(title, Vector2(0.5, 0.5), 12, "center")
		await _point(title, Vector2(0.98, 0.55), 20, "right")
		await _point(title, Vector2(1.0, 1.0), 20, "corner")
		await _point(title, Vector2(0.03, 0.10), 20, "left_up")
		await _point(title, Vector2(0.5, 0.5), 24, "back_center")
		# 快速划过：冲量在停手以后还会把画面带过去一点（过冲），最后停在鼠标位置上。
		await _point(title, Vector2(0.5, 0.5), 2, "swipe_start")
		for i in 7:
			_push(title, Vector2(0.5, 0.5).lerp(Vector2(0.95, 0.5), float(i) / 6.0))
			await _frames(1)
		var peak := 0.0
		var peak_frame := 0
		for i in 50:
			await _frames(1)
			if absf(title.sway().x) > peak:
				peak = absf(title.sway().x)
				peak_frame = Engine.get_frames_drawn() - 1
		print("SHOT swipe_peak %d  sway=%.3f（停在 0.90，超出的就是过冲）" % [peak_frame, peak])
		await _frames(30)
		print("SHOT swipe_settled %d  sway=%s" % [Engine.get_frames_drawn() - 1, title.sway()])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		get_tree().quit()

	func _point(title: Title, at: Vector2, frames: int, name: String) -> void:
		_push(title, at)
		await _frames(frames)
		print("SHOT %s %d  sway=%s" % [name, Engine.get_frames_drawn() - 1, title.sway()])

	func _push(title: Title, at: Vector2) -> void:
		# push_input 收窗口坐标，at 是画布比例；用视口的最终变换换算过去。
		var ev := InputEventMouseMotion.new()
		ev.position = title.get_viewport().get_final_transform() * (at * title.size)
		get_tree().root.push_input(ev)

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame
