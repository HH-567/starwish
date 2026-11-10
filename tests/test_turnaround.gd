extends Node
## 真结局最后一棒：终章里从科学家的虫洞掉头冲刺，必须能撞碎噬光者（F6 那条路）。
## 关键点（踩过的坑）：
##   · 出口朝向和噬光者不在一条走廊上 → 冲出去是背对着它跑，永远撞不上；
##   · 冲刺路上撞碎墙会减速 → 两道墙就掉出阶段 5，撞上了也撞不碎。
##   godot --headless --path . --fixed-fps 60 res://tests/test_turnaround.tscn

const PATH := "user://test_turnaround_save.json"

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())

class Runner extends Node:
	var _failures := 0

	func _ready() -> void:
		Save.path = PATH
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		Game.debug_no_decay = true
		Game.debug_no_enemies = true
		Game.debug_rescue_all()
		Game.flow = Game.Flow.CHASE
		Save.checkpoint = ""
		get_tree().change_scene_to_file(Game.FINALE_SCENE)
		await get_tree().process_frame
		await get_tree().process_frame
		var finale := get_tree().current_scene
		var player := get_tree().get_first_node_in_group(&"player") as Player
		var boss := get_tree().get_first_node_in_group(&"boss") as Boss
		_check("全救之后终章里有科学家的虫洞", await _until(func() -> bool: return _worm() != null))
		var wh := _worm()
		_check("那是「掉头冲刺」的虫洞", wh.charge)
		for i in 600:
			if boss.state == Boss.State.CHASE:
				break
			await get_tree().physics_frame
		_check("噬光者进入追逐", boss.state == Boss.State.CHASE)
		var a := (wh.get_node(^"A") as Node2D).global_position
		# 小星以阶段 5 从右边冲进虫洞，噬光者在后面追
		player.global_position = a + Vector2(240.0, 0.0)
		player.velocity = Vector2.LEFT * 900.0
		boss.global_position = a + Vector2(760.0, 0.0)
		var warped := false
		var lowest_stage := 9
		var smashed := false
		for i in 300:
			await get_tree().physics_frame
			if player.charged:
				warped = true
				lowest_stage = mini(lowest_stage, player.stage)
			if boss.state == Boss.State.SHATTERED:
				smashed = true
				break
		_check("进了虫洞、带着冲刺状态出来", warped)
		_check("冲刺路上一直是阶段 5（撞墙不减速）", lowest_stage >= 5, "最低阶段 %d" % lowest_stage)
		_check("撞碎噬光者", smashed, "噬光者状态 %d" % boss.state)
		_check("真结局：进连环画", await _until(func() -> bool:
			return Game.flow == Game.Flow.ENDING and Game.ending == &"hidden" and get_tree().current_scene != null \
				and get_tree().current_scene.scene_file_path == Game.ENDING_COMIC_SCENE))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
		get_tree().quit(1 if _failures > 0 else 0)

	func _worm() -> Wormhole:
		for hp in get_tree().current_scene.find_children("*", "HelpPoint", true, false):
			if (hp as HelpPoint).role == "scientist":
				return (hp as HelpPoint).get_node_or_null(^"Wormhole") as Wormhole
		return null

	func _until(cond: Callable, max_frames := 900) -> bool:
		for i in max_frames:
			if cond.call():
				return true
			await get_tree().process_frame
		return cond.call()

	func _check(name: String, ok: bool, detail := "") -> void:
		if not ok:
			_failures += 1
		print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
