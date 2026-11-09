extends Node
## 设置：音量 / 难度开关。
##   godot --headless --path . --fixed-fps 60 res://tests/test_settings.tscn

var _failures := 0

func _check(what: String, ok: bool, note := "") -> void:
	if ok:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what, "  ", note)

## 播一次 hit，返回它实际用的音量（dB）
## 无头模式下 playing 不一定立刻为 true，所以按轮转索引取那个播放器。
func _hit_volume() -> float:
	Audio.locked = false
	Audio._last_time.clear()
	Audio.play(&"hit")
	var n := Audio._players.size()
	var idx := (Audio._next - 1 + n) % n
	return Audio._players[idx].volume_db

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	await get_tree().process_frame

	# 音量：调小之后正在播的音效跟着小
	Save.sfx_volume = 1.0
	Save.music_volume = 1.0
	Audio.apply_volume()
	var loud := _hit_volume()
	Save.sfx_volume = 0.2
	Audio.play(&"hit")
	Audio.apply_volume()
	var quiet := _hit_volume()
	_check("音效调小后音量下降", loud > quiet, "%.1f -> %.1f" % [loud, quiet])
	Save.sfx_volume = 1.0
	Save.music_volume = 1.0
	Audio.apply_volume()

	# 难度：三档的行为开关
	Save.difficulty = 0
	_check("微光级：救人回光", Game.rescue_refills())
	_check("微光级：补给不筛", not Game.keeps_shards_only_near_enemies())
	_check("微光级：衰减不变", is_equal_approx(Game.decay_mult(), 1.0))

	Save.difficulty = 1
	_check("长夜级：救人不回光", not Game.rescue_refills())
	_check("长夜级：补给只留敌人附近", Game.keeps_shards_only_near_enemies())
	_check("长夜级：不加敌人", not Game.extra_enemies())

	Save.difficulty = 2
	_check("永夜级：衰减更快", Game.decay_mult() > 1.0, "%.2f" % Game.decay_mult())
	_check("永夜级：加敌人", Game.extra_enemies())

	# 设置面板能开、能关
	Game.flow = Game.Flow.TITLE
	var panel := (load("res://scenes/ui/settings.tscn") as PackedScene).instantiate()
	add_child(panel)
	await get_tree().process_frame
	_check("设置面板能实例化", is_instance_valid(panel))
	panel.call("_bump", "sfx", -1)
	_check("按一下音量按钮数值会变", Save.sfx_volume < 1.0, "%.1f" % Save.sfx_volume)
	panel.call("_close")
	await get_tree().process_frame
	_check("关闭后面板被回收", not is_instance_valid(panel))

	Save.difficulty = 0
	Save.sfx_volume = 1.0
	Save.music_volume = 1.0
	Save.clear()
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)
