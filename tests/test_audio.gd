extends Node
## 音效测试：音效都在、没解锁时不播、解锁后由 Game 的信号触发、冷却内的重复触发会丢掉；
## 带位置的音效离太远不播；循环音没人续命就淡出停掉。
##   godot --headless --path . res://tests/test_audio.tscn

var _failures := 0

func _ready() -> void:
	Audio.locked = true
	Audio.count = 0
	Audio.last_played = &""

	# 原来的 10 个 + tools/sfx_synth.py 合成的一次性音效 19 个；循环音 3 个另算。
	_check("一次性音效都加载进来了", Audio.STREAMS.size() == 29, "%d 个" % Audio.STREAMS.size())
	_check("循环音都加载进来了", Audio.LOOPS.size() == 3, "%d 个" % Audio.LOOPS.size())
	var missing: Array[String] = []
	for id: StringName in Audio.STREAMS:
		if Audio.STREAMS[id] == null or not Audio.STREAMS[id] is AudioStream:
			missing.append(String(id))
	for id: StringName in Audio.LOOPS:
		var loop := Audio.LOOPS[id] as AudioStreamWAV
		if loop == null or loop.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			missing.append(String(id) + "（没开循环）")
	_check("每个音效都是能播的流", missing.is_empty(), "%s" % [missing])

	# Web 上的规矩：第一次输入之前不播。
	Audio.play(&"rescue")
	_check("没解锁：不播", Audio.count == 0)

	Audio.unlock()
	Audio.play(&"rescue")
	_check("解锁后能播", Audio.count == 1 and Audio.last_played == &"rescue")

	# 冷却：同一个音效连着触发只响一次。
	Audio.play(&"rescue")
	_check("冷却内的重复触发丢掉", Audio.count == 1)
	Audio.play(&"hit")
	_check("换一种音效照常播", Audio.count == 2 and Audio.last_played == &"hit")

	# 信号接线：救到人、烧藤、撞墙、过关、噬光者登场。
	# 每种音效有冷却，前面直接播过，这里先等冷却过去。
	await get_tree().create_timer(0.5).timeout
	Audio.count = 0
	Save.rescued["test/npc"] = &"watchman"
	Game.npc_rescued.emit("test/npc")
	_check("救到人：响救人音", Audio.last_played == &"rescue")
	Audio.last_played = &""
	Game.vine_burnt.emit("test/vine")
	_check("烧断影藤：响烧的音", Audio.last_played == &"burn")
	Audio.last_played = &""
	Game.player_hit.emit(&"hurt")
	_check("受伤：响撞墙音", Audio.last_played == &"hit")
	Audio.last_played = &""
	Game.player_hit.emit(&"bounce")
	_check("反弹：响一声轻的弹墙音", Audio.last_played == &"bounce")
	Audio.last_played = &""
	Game.player_hit.emit(&"smash")
	_check("阶段 5 撞碎墙：响撞碎音", Audio.last_played == &"smash")
	Audio.last_played = &""
	Game.player_hit.emit(&"stop")
	_check("软垫急停：响软垫音", Audio.last_played == &"stop")
	Audio.last_played = &""
	Game.checkpoint_reached.emit("test/cp")
	_check("点亮检查点：响检查点音", Audio.last_played == &"checkpoint")
	# 换档：1 → 2 预警，2 → 3 往上走的风声，往下掉不响。
	Audio.last_played = &""
	Game.speed_stage_changed.emit(1)
	Game.speed_stage_changed.emit(2)
	_check("掉进阶段 2：响预警", Audio.last_played == &"warn")
	Audio.last_played = &""
	Game.speed_stage_changed.emit(3)
	_check("升到阶段 3：响升档", Audio.last_played == &"gear")
	Audio.last_played = &""
	Game.speed_stage_changed.emit(2)
	_check("往下掉档不响", Audio.last_played == &"")
	Game.speed_stage_changed.emit(1)
	Audio.last_played = &""
	Game.chapter_cleared.emit(&"ch0")
	_check("过关：响过关音", Audio.last_played == &"clear")
	Audio.last_played = &""
	Game.boss_state_changed.emit(Boss.State.EMERGE)
	_check("噬光者登场：响登场音", Audio.last_played == &"boss")
	Audio.last_played = &""
	Game.boss_state_changed.emit(Boss.State.CHASE)
	_check("普通状态不响", Audio.last_played == &"")

	await _positional_and_loops()
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## 带位置的音效：镜头附近能播、太远不播；循环音续命时在响，不续命自己停。
func _positional_and_loops() -> void:
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var near := Audio.play_at(&"shot", cam.get_screen_center_position() + Vector2(100, 0))
	_check("镜头附近的带位置音效能播", near != null and near.playing)
	var far := Audio.play_at(&"meteor", cam.get_screen_center_position() + Vector2(5000, 0))
	_check("离镜头太远的带位置音效不播", far == null)
	for i in 5:
		Audio.hold(&"test_wind", &"wind", 1.0, 1.2)
		await get_tree().process_frame
	_check("循环音续命时在响", Audio.loop_count() == 1)
	for i in 40:
		await get_tree().process_frame
	_check("没人续命：循环音淡出后停掉", Audio.loop_count() == 0, "%d 个" % Audio.loop_count())
	# 连着捡小星星：一颗比一颗高。
	Audio._last_time.clear()
	Audio.play_shard()
	var first := _last_pitch()
	await get_tree().create_timer(0.1).timeout
	Audio.play_shard()
	var second := _last_pitch()
	_check("连着捡小星星，音一颗比一颗高", second > first * 1.05, "%.2f → %.2f" % [first, second])
	cam.queue_free()

func _last_pitch() -> float:
	var n := Audio._players.size()
	return Audio._players[(Audio._next - 1 + n) % n].pitch_scale

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
