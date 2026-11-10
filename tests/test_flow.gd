extends Node
## 流程测试（按章节表跑，表里有几章就测几章）：标题 → 新游戏 → 第一章 → 检查点 → 死亡从检查点复活 → 暂停
## → 一章章通关 → 最后一章通关进终章 → 跑过赛道的 Entry 记成检查点 → 死亡从那里重来
## → 回标题再继续回到那里 → 跑到逃离点进正常结局 → 存档记下结局 → 回标题不能再继续。
##   godot --headless --path . --fixed-fps 60 res://tests/test_flow.tscn
## 流程会换场景，测试场景自己会被删掉，所以测试逻辑放在挂到 root 下的 Runner 上。

const PATH := "user://test_flow_save.json"

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())

class Runner extends Node:
	var _failures := 0
	## 章节表里的 id，按顺序。
	var _ids: Array[StringName] = []

	func _ready() -> void:
		Save.path = PATH
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		Game.debug_no_decay = true
		Game.debug_no_enemies = true
		_ids.assign(Game.chapters.map(func(c: Array) -> StringName: return c[0]))
		var finished: Variant = await _run()
		_check("全部步骤都跑完了", finished == true)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
		get_tree().quit(1 if _failures > 0 else 0)

	func _run() -> bool:
		get_tree().change_scene_to_file(Game.TITLE_SCENE)
		_check("进标题", await _until(func() -> bool: return Game.flow == Game.Flow.TITLE))
		_check("没有存档：不能继续", not Game.can_continue())

		Game.start_new()
		_check("新游戏：进第一章 %s" % _ids[0], await _until(func() -> bool: return _playing(_ids[0])))
		_check("进章节就写存档", _disk().get("chapter") == String(_ids[0]))

		var cp := _find(Checkpoint) as Checkpoint
		var cp_id := cp.save_id
		var cp_pos := cp.global_position
		_player().global_position = cp_pos
		_check("到检查点：写进存档", await _until(func() -> bool: return _disk().get("checkpoint") == cp_id))

		# 复活会重新加载整章，旧的节点都没了，下面只用记下来的位置。
		Game.player_died.emit(Player.Death.EXTINGUISHED)
		_check("死亡：从检查点复活", await _until(func() -> bool: return Game.flow == Game.Flow.PLAYING and _player() != null and _player().global_position.distance_to(cp_pos) < 1.0))

		Game.toggle_pause()
		_check("Esc 暂停", get_tree().paused and Game.flow == Game.Flow.PAUSED)
		Game.toggle_pause()
		_check("再按一次继续", not get_tree().paused and Game.flow == Game.Flow.PLAYING)

		# 一章章通关：中间每章下一章是同表里的下一个 id，最后一章进终章。
		for i in _ids.size():
			_player().global_position = (_find(Exit) as Node2D).global_position
			if i + 1 < _ids.size():
				_check("第 %d 章通关：进第 %d 章 %s" % [i + 1, i + 2, _ids[i + 1]], await _until(func() -> bool: return _playing(_ids[i + 1])))
				_check("通关后存档记下一章，检查点清空", _disk().get("chapter") == String(_ids[i + 1]) and _disk().get("checkpoint") == "")
			else:
				_check("最后一章通关：进终章", await _until(func() -> bool: return Game.flow == Game.Flow.CHASE and get_tree().current_scene is Finale and _player() != null))
		_check("进终章就写存档，从开头出发", _disk().get("chapter") == Game.FINALE_ID and _disk().get("checkpoint") == "")

		var finale := get_tree().current_scene as Finale
		await _until(func() -> bool: return finale.boss.state == Boss.State.CHASE)
		# 复活会重新加载终章，下面只用记下来的 id 和位置。
		var entry_id := Save.id_of(finale.entries[0])
		var entry_pos := finale.entries[0].global_position
		_player().global_position = entry_pos + Vector2.LEFT * 64.0
		_check("跑过赛道的 Entry：记成检查点写进存档", await _until(func() -> bool: return _disk().get("checkpoint") == entry_id), entry_id)
		Game.player_died.emit(Player.Death.DRAINED)
		_check("终章里死了：从那段赛道的 Entry 重来", await _until(func() -> bool: return _at_finale_checkpoint(entry_pos)))

		Game.to_title()
		_check("终章里回标题：能继续", await _until(func() -> bool: return Game.flow == Game.Flow.TITLE) and Game.can_continue())
		Game.continue_game()
		_check("继续：回到终章的检查点", await _until(func() -> bool: return _at_finale_checkpoint(entry_pos)))

		await _until(func() -> bool: return _player().state == Player.State.ACTIVE)
		_player().global_position = (_find(EscapePoint) as Node2D).global_position
		_check("跑到逃离点：进正常结局", await _until(func() -> bool: return Game.flow == Game.Flow.ENDING and get_tree().current_scene != null and get_tree().current_scene.scene_file_path == Game.ENDING_NORMAL_SCENE))
		_check("存档记下正常结局，没有可继续的章节", _disk().get("endings", {}).get("main") == true and _disk().get("chapter") == "")

		Game.to_title()
		_check("结局后回标题：不能再继续", await _until(func() -> bool: return Game.flow == Game.Flow.TITLE) and not Game.can_continue())
		return true

	func _check(name: String, ok: bool, detail := "") -> void:
		if not ok:
			_failures += 1
		print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])

	## 一帧帧等到 cond 成立，最多等 max_frames 帧。
	func _until(cond: Callable, max_frames := 900) -> bool:
		for i in max_frames:
			if cond.call():
				return true
			await get_tree().process_frame
		return cond.call()

	func _playing(chapter_id: StringName) -> bool:
		var scene := get_tree().current_scene as Chapter
		return Game.flow == Game.Flow.PLAYING and scene != null and scene.chapter_id == chapter_id and _player() != null and _player().state == Player.State.ACTIVE

	func _at_finale_checkpoint(at: Vector2) -> bool:
		return Game.flow == Game.Flow.CHASE and get_tree().current_scene is Finale and _player() != null and _player().global_position.distance_to(at) < 1.0

	func _player() -> Player:
		return get_tree().get_first_node_in_group(&"player") as Player

	func _find(type: Variant) -> Node:
		for node in get_tree().current_scene.find_children("*", "", true, false):
			if is_instance_of(node, type):
				return node
		return null

	func _disk() -> Dictionary:
		if not FileAccess.file_exists(PATH):
			return {}
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		return data if data is Dictionary else {}
