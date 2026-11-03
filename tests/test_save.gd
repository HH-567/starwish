extends Node
## 存档读写测试：写进临时文件再读回来内容一样；读不懂或版本不对当作没有存档；新游戏清进度、留结局。
##   godot --headless --path . res://tests/test_save.tscn

const PATH := "user://test_save.json"

var _failures := 0

func _ready() -> void:
	Save.path = PATH
	Save.read()
	Save.chapter = "ch2"
	Save.checkpoint = "ch2/Level/Entities/Checkpoint"
	Save.rescued["ch0/Level/Entities/Npc"] = &"watchman"
	Save.mail["ch1/Level/Entities/Npc2"] = &"doctor"
	Save.broken["ch3/Level/Entities/CrackedWall"] = true
	Save.burnt["ch1/Level/Entities/ShadowVine"] = true
	Save.endings["main"] = true
	Save.write()
	var expected := _snapshot()
	Save.clear()
	Save.endings.clear()
	Save.read()
	_check("写进去再读回来一样", _snapshot() == expected, _snapshot())
	_check("读回来的职业是 StringName，按职业查得到", typeof(Save.rescued["ch0/Level/Entities/Npc"]) == TYPE_STRING_NAME and Save.has_role(&"watchman"))
	Save.clear()
	_check("新游戏清进度、留结局记录", Save.rescued.is_empty() and Save.mail.is_empty() and Save.chapter == "" and Save.endings.get("main") == true)
	_write_raw(JSON.stringify({"version": 1, "chapter": "ch3", "endings": {"main": true}}))
	Save.read()
	_check("版本不对当作没有存档", Save.chapter == "" and Save.endings.is_empty())
	_write_raw("这不是 JSON")
	Save.read()
	_check("读不懂当作没有存档", Save.chapter == "" and Save.rescued.is_empty())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_check("没有存档文件时 exists() 为假", not Save.exists())
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])

func _snapshot() -> String:
	return JSON.stringify([Save.chapter, Save.checkpoint, Save.rescued, Save.mail, Save.broken, Save.burnt, Save.endings])

func _write_raw(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()
