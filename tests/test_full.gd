extends Node
## 正式章节全表体检（不带测试关）：
## 章节表里正好 12 个人、职业不重不漏；把他们全记成已救之后，终章按倒序接上五段赛道，
## 科学家的帮助点和他的掉头虫洞出现（隐藏结局的入口），逃离点也在。
##   godot --headless --path . --fixed-fps 60 res://tests/test_full.tscn

## 全游戏 12 个职业，各一个。
const ROLES := [
	"watchman", "gardener", "doctor", "painter", "guide", "miner",
	"locksmith", "postman", "musician", "listener", "clockmaker", "scientist",
]

var _failures := 0

func _ready() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Save.clear()

	var roles: Array[String] = []
	for chapter: Array in Game.chapters:
		var root := (load(chapter[1]) as PackedScene).instantiate()
		for npc: Npc in root.find_children("*", "Npc", true, false):
			roles.append(npc.role)
		root.free()
	roles.sort()
	var expected := ROLES.duplicate()
	expected.sort()
	_check("章节表里正好 %d 个人" % Game.NPC_TOTAL, roles.size() == Game.NPC_TOTAL, "%d" % roles.size())
	_check("12 个职业各一个，不重不漏", roles == expected, "%s" % [roles])
	_check("还没救人：不能走隐藏结局", not Game.everyone_rescued())

	# 全部救出，开终章。
	for chapter: Array in Game.chapters:
		var root := (load(chapter[1]) as PackedScene).instantiate()
		for npc: Npc in root.find_children("*", "Npc", true, false):
			Save.rescued[Save.id_of(npc)] = StringName(npc.role)
		root.free()
	_check("全救出：可以走隐藏结局", Game.everyone_rescued())

	var finale := (load(Game.FINALE_SCENE) as PackedScene).instantiate() as Finale
	add_child(finale)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var lanes: Array[String] = []
	for child in finale.get_children():
		if child is Chapter:
			lanes.append(String((child as Chapter).chapter_id))
	var want: Array[String] = []
	for i in range(Game.chapters.size() - 1, -1, -1):
		want.append(String(Game.chapters[i][0]))
	_check("终章按章节倒序接上五段赛道", lanes == want, "%s" % [lanes])
	_check("检查点是五段赛道加结尾的 Entry", finale.entries.size() == lanes.size() + 1, "%d" % finale.entries.size())
	_check("终章里有噬光者", get_tree().get_first_node_in_group(&"boss") != null)

	var scientist: HelpPoint = null
	for help: HelpPoint in finale.find_children("*", "HelpPoint", true, false):
		if help.role == "scientist":
			scientist = help
	_check("全救出：科学家的帮助点出现", scientist != null and scientist.everyone)
	var worm: Wormhole = null
	if scientist != null:
		for node in scientist.find_children("*", "Wormhole", true, false):
			worm = node as Wormhole
		_check("科学家放下掉头的虫洞", worm != null and worm.charge and not worm.keep_direction)
	_check("结尾的逃离点还在", finale.find_children("*", "EscapePoint", true, false).size() == 1)

	# 隐藏结局的入口真的能用：以阶段 5 钻进科学家的虫洞，出来时被 charge、朝来路冲回去。
	if worm != null:
		# 等噬光者开始追、小星解锁，才能进虫洞（WARP 只从 ACTIVE 进）。
		for i in 600:
			await get_tree().physics_frame
			if finale.boss.state == Boss.State.CHASE and finale.player.state == Player.State.ACTIVE:
				break
		var player := finale.player
		var entry := worm.get_node(^"A") as Node2D
		player.velocity = Vector2(920.0, 0.0)
		player.global_position = entry.global_position
		for i in 6:
			await get_tree().physics_frame
		_check("钻进科学家的虫洞：被 charge", player.charged, "状态 %s" % Player.State.keys()[player.state])
		for i in 20:
			await get_tree().physics_frame
		_check("出来之后朝 +X 冲回去（阶段 5 的速度）", player.velocity.x > 0.0 and player.velocity.length() > 700.0, "%s" % player.velocity)
		# 把噬光者摆到冲回来的路上：掉头撞碎它，进隐藏结局。
		var shattered := false
		for i in 120:
			finale.boss.global_position = player.global_position + Vector2(30.0, 0.0)
			await get_tree().physics_frame
			if finale.boss.state == Boss.State.SHATTERED:
				shattered = true
				break
		_check("掉头撞碎噬光者（隐藏结局）", shattered, "噬光者状态 %d" % finale.boss.state)

	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
