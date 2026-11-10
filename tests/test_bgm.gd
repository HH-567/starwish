extends Node
## 九首 BGM 的交付检查：文件在、是 ogg、能加载、循环真的开着、play_bgm 能切过去。
##   godot --headless --path . --fixed-fps 60 res://tests/test_bgm.tscn

const IDS := [&"title", &"ch0", &"ch1", &"ch2", &"ch3", &"ch4", &"chase", &"ending_normal", &"ending_hidden"]

func _ready() -> void:
	var failures := 0
	for id: StringName in IDS:
		var path := "res://audio/bgm/%s.ogg" % id
		if not ResourceLoader.exists(path):
			print("FAIL  %-14s 缺文件 %s" % [id, path])
			failures += 1
			continue
		var stream := load(path)
		if not (stream is AudioStreamOggVorbis):
			print("FAIL  %-14s 不是 ogg" % id)
			failures += 1
			continue
		Audio.play_bgm(id)
		await get_tree().process_frame
		var ogg := stream as AudioStreamOggVorbis
		var current: StringName = Audio.get("_bgm_current")
		var ok := current == id and ogg.loop and ogg.get_length() > 30.0
		if not ok:
			failures += 1
		print("%s  %-14s 时长 %.1fs  循环 %s  当前 %s" % [
			"PASS" if ok else "FAIL", id, ogg.get_length(), ogg.loop, current])
	# 别把 BGM 状态留给下一个测试
	Audio.set("_bgm_current", &"")
	print("RESULT %s，失败 %d 项" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)