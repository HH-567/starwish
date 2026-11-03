extends Node
## 音效测试：十个音效都在、没解锁时不播、解锁后由 Game 的信号触发、冷却内的重复触发会丢掉。
##   godot --headless --path . res://tests/test_audio.tscn

var _failures := 0

func _ready() -> void:
	Audio.locked = true
	Audio.count = 0
	Audio.last_played = &""

	_check("十个音效都加载进来了", Audio.STREAMS.size() == 10)
	var missing: Array[String] = []
	for id: StringName in Audio.STREAMS:
		if Audio.STREAMS[id] == null or not Audio.STREAMS[id] is AudioStream:
			missing.append(String(id))
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
	_check("反弹不响，免得吵", Audio.last_played == &"")
	Audio.last_played = &""
	Game.chapter_cleared.emit(&"ch0")
	_check("过关：响过关音", Audio.last_played == &"clear")
	Audio.last_played = &""
	Game.boss_state_changed.emit(Boss.State.EMERGE)
	_check("噬光者登场：响登场音", Audio.last_played == &"boss")
	Audio.last_played = &""
	Game.boss_state_changed.emit(Boss.State.CHASE)
	_check("普通状态不响", Audio.last_played == &"")

	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
