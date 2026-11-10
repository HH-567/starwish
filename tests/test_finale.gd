extends Node
## 终章的无头测试：拼接、帮助点按救人情况出现、隧道、开头锁住、检查点和复活、帮助的效果、两种结局，
## 最后让小星自己从头跑：一个都没救跑到逃离点（正常结局）；全救了跑到终点就是真结局，
## 从科学家的虫洞掉头撞碎噬光者也是真结局（隐藏结局）。
##   godot --headless --path . --fixed-fps 60 res://tests/test_finale.tscn
## 直接运行终章场景（不经过标题，不写存档）。会换场景，所以测试逻辑放在挂到 root 下的 Runner 上。

const PATH := "user://test_finale_save.json"
## 终章的多段拼接要几段赛道才测得出来；正式章节还没做完，这里把两张测试关当章节用。
## 正式章节齐了之后，这个测试改成直接跑 Game.CHAPTERS。
const TEST_CHAPTERS := [
	[&"test_light", "res://scenes/levels/test_light.tscn"],
	[&"test_feel", "res://scenes/levels/test_feel.tscn"],
]
## 自己跑的路线：[段, 列, 行]。段是 Intro、Outro 或章节 id，列和行是那一段地图里的格子。
## 小星一直往左，上下朝前面（左边）最近的那个路点所在的行靠。
const ROUTE_NONE := [
	["test_light", 87, 8],
	# 没有矿工的隧道：从那一大块墙上面绕过去。
	["test_light", 52, 3],
	["test_light", 39, 3],
	["test_light", 30, 8],
	["Outro", 0, 8],
]
const ROUTE_ALL := [
	["test_light", 0, 8],
	# 结尾：靠到下半边，冲进科学家的虫洞。
	["Outro", 46, 8],
	["Outro", 20, 11],
]

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())

class Runner extends Node:
	var _failures := 0
	var _deaths := 0
	var _helps: Array[StringName] = []
	## 追逐里噬光者贴得最近时的距离，用来说明"没帮助时有多险"。
	var _min_gap := 99999.0
	## 赛道上的加速带：一共几段、最多同时亮了几段（点灯的人铺完应该是全部）。
	var _strip_total := 0
	var _strip_lit := 0
	var _checkpoints: Array[String] = []

	func _ready() -> void:
		Save.path = PATH
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		Game.chapters = TEST_CHAPTERS
		Game.player_died.connect(func(_c: int) -> void: _deaths += 1)
		Game.help_triggered.connect(func(role: StringName) -> void: _helps.append(role))
		Game.checkpoint_reached.connect(func(id: String) -> void: _checkpoints.append(id))
		var finished: Variant = await _run()
		_check("全部步骤都跑完了", finished == true)
		_steer(0)
		Input.action_release("move_left")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
		print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
		get_tree().quit(1 if _failures > 0 else 0)

	func _check(name: String, ok: bool, detail := "") -> void:
		if not ok:
			_failures += 1
		print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])

	## 一帧帧等到 cond 成立，最多等 max_frames 帧。
	func _until(cond: Callable, max_frames := 900) -> bool:
		for i in max_frames:
			if cond.call():
				return true
			await get_tree().physics_frame
		return cond.call()

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().physics_frame

	func _finale() -> Finale:
		return get_tree().current_scene as Finale

	func _in_ending() -> bool:
		var scene := get_tree().current_scene
		return Game.flow == Game.Flow.ENDING and scene != null and scene.scene_file_path == Game.ending_scene(Game.ending)

	func _run() -> bool:
		_check("各章的小人一共 NPC_TOTAL 个", _npc_count() == Game.NPC_TOTAL, "%d" % _npc_count())

		# 全救了：拼接、帮助点、隧道、开头锁住、检查点、帮助的效果、复活，最后跑到终点就是真结局（不用撞碎噬光者）。
		Game.debug_no_decay = true
		Game.debug_no_enemies = true
		# 迷宫本身用 tools/probe_maze 验；这里只验追逐、加速带和结局分支。
		Game.debug_flat_maze = true
		_rescue_all()
		_check("全救了", Game.everyone_rescued())
		_check("打开终章", await _open())
		var finale := _finale()
		var lanes := _lanes(finale)
		_check("赛道按章节倒序接上", lanes.map(func(c: Chapter) -> StringName: return c.chapter_id) == [&"test_feel", &"test_light"])
		_check("赛道是终章模式：没有关卡区", lanes.all(func(c: Chapter) -> bool: return c.mode == Chapter.Mode.FINALE and c.get_node_or_null(^"Level") == null))
		var ends: Array[Vector2] = [(finale.get_node(^"Intro/Exit") as Node2D).global_position]
		for lane in lanes:
			ends.append((lane.get_node(^"ChaseLane/Entry") as Node2D).global_position)
			ends.append((lane.get_node(^"ChaseLane/Exit") as Node2D).global_position)
		ends.append((finale.get_node(^"Outro/Entry") as Node2D).global_position)
		var joined := true
		for i in range(0, ends.size(), 2):
			joined = joined and ends[i].distance_to(ends[i + 1]) < 0.01
		_check("每段的 Entry 对齐上一段的 Exit", joined, "%s" % [ends])
		_check("检查点是每段赛道和结尾的 Entry", finale.entries.size() == lanes.size() + 1)
		_check("全救了：帮助点都在，加上结尾的科学家", _help_points(finale).size() == _help_total(), "%d / %d" % [_help_points(finale).size(), _help_total()])
		var tunnels := finale.find_children("*", "Tunnel", true, false)
		var tunnel_at := (tunnels[0] as Node2D).global_position if tunnels.size() == 1 else Vector2.INF
		_check("矿工救了：隧道存在，但还没挖开（等玩家到）", tunnels.size() == 1 and _wall_at(finale, tunnel_at))
		var worms := finale.find_children("*", "Wormhole", true, false)
		_check("画家的光门和科学家的掉头虫洞都在", worms.size() == 2 and worms.any(func(w: Wormhole) -> bool: return w.charge and not w.keep_direction))
		var lamps := finale.find_children("*", "Lamp", true, false)
		_check("守夜人的路灯都在，还没亮", lamps.size() > 1 and lamps.all(func(l: Lamp) -> bool: return not l.lit))

		var p := finale.player
		var boss := finale.boss
		_check("开头：噬光者登场时小星动不了", await _until(func() -> bool: return p.state == Player.State.LOCKED) and boss.state == Boss.State.EMERGE)
		_check("噬光者开始追：小星能动了", await _until(func() -> bool: return boss.state == Boss.State.CHASE) and p.state == Player.State.ACTIVE)

		var watchman := _help(finale, "watchman")
		# 真的跑过去时小星不一定正好踩在帮助点上，可能差着几格：站高两格再进圈。
		p.global_position = watchman.global_position + Vector2(0.0, -96.0)
		await _frames(2)
		_check("经过守夜人：有盾", p.shield and _helps.has(&"watchman"))
		# 终章太快，帮助要特写 + 慢放，不然玩家根本注意不到（实测的节奏问题）。
		var cam := p.get_node(^"Camera") as Camera2D
		_check("拿到帮助：慢放", Engine.time_scale < 0.9, "time_scale=%.2f" % Engine.time_scale)
		await _frames(10)
		# 守夜人的帮忙只作用在小星身上 → 特写看小人（玩家要看清"谁给的盾"）
		var half := get_viewport().get_visible_rect().size / cam.zoom * 0.5
		var sees_help := absf(cam.global_position.y - watchman.global_position.y) < half.y
		_check("特写对着帮忙的小人", sees_help, "半高 %.0f / 差 %.0f" % [
			half.y, absf(cam.global_position.y - watchman.global_position.y)])
		await _frames(90)
		_check("特写结束：时间恢复、镜头回到小星", is_equal_approx(Engine.time_scale, 1.0) and cam.global_position.distance_to(p.global_position) < 300.0, "time_scale=%.2f" % Engine.time_scale)
		_check("跑过两段的 Entry：检查点记成后一段的", Save.checkpoint == "test_light/ChaseLane/Entry" and _checkpoints == ["test_feel/ChaseLane/Entry", "test_light/ChaseLane/Entry"], "%s" % [_checkpoints])
		lamps.sort_custom(func(a: Lamp, b: Lamp) -> bool: return a.global_position.distance_to(watchman.global_position) < b.global_position.distance_to(watchman.global_position))
		await _frames(20)
		_check("路灯由近到远亮起来", lamps[0].lit and not lamps[-1].lit)
		_check("路灯全亮", await _until(func() -> bool: return lamps.all(func(l: Lamp) -> bool: return l.lit), 240))
		p.light = 10.0
		p.global_position = _help(finale, "doctor").global_position
		await _frames(2)
		_check("经过医生：亮度回满", p.light == p.light_max, "%.1f / %.1f" % [p.light, p.light_max])
		p.global_position = _help(finale, "clockmaker").global_position
		await _frames(2)
		_check("经过钟表匠：噬光者减速", boss._slow_left > 0.0 and _helps.has(&"clockmaker"))
		p.global_position = _help(finale, "musician").global_position
		var before := boss.gap()
		await _frames(2)
		_check("经过乐手：噬光者被震退", boss.gap() > before + Game.tuning.help_knockback - 60.0, "%.0f → %.0f" % [before, boss.gap()])

		var entry := (lanes[1].get_node(^"ChaseLane/Entry") as Node2D).global_position
		# 重新加载后旧的终章就没了，lambda 里只记它的 id。
		var old_id := finale.get_instance_id()
		Game.player_died.emit(Player.Death.DRAINED)
		_check("死了：重新加载终章", await _until(func() -> bool: return _finale() != null and _finale().get_instance_id() != old_id and _finale().player != null))
		finale = _finale()
		p = finale.player
		boss = finale.boss
		_check("从检查点出来，带着朝左的初速", p.global_position.distance_to(entry) < 0.5 and is_equal_approx(p.velocity.x, -Game.tuning.chase_respawn_speed), "%s %s" % [p.global_position, p.velocity])
		_check("噬光者在身后 boss_gap_start 处重新出现", boss.state == Boss.State.EMERGE and boss.global_position.distance_to(entry + Vector2.RIGHT * Game.tuning.boss_gap_start) < 0.5)
		_check("复活后没在开头，不锁小星", await _until(func() -> bool: return p.state == Player.State.ACTIVE, 60))

		p.global_position = (finale.find_children("*", "EscapePoint", true, false)[0] as Node2D).global_position
		_check("跑到逃离点：小星停下，噬光者退回黑暗", await _until(func() -> bool: return boss.state == Boss.State.RETREAT, 30) and p.state == Player.State.LOCKED)
		_check("全救了：跑到终点就是真结局（不用撞碎噬光者）",
			await _until(_in_ending) and Game.ending == &"hidden" and Save.endings.get("hidden") == true
				and get_tree().current_scene.scene_file_path == Game.ENDING_COMIC_SCENE,
			"ending=%s" % Game.ending)

		# 一个都没救：没有帮助点，隧道是墙；自己跑到逃离点。
		Game.debug_no_decay = false
		Save.clear()
		_check("打开终章（一个都没救）", await _open())
		finale = _finale()
		_check("没救人：没有帮助点", _help_points(finale).is_empty())
		_check("赛道一开始加速带是收着的", _strips(finale).size() > 0 and _strips(finale).all(func(s: AccelStrip) -> bool: return not s.deployed),
				"%d 段" % _strips(finale).size())
		_strip_total = _strips(finale).size()
		_strip_lit = 0
		_check("没救矿工：隧道那里还是墙", _wall_at(finale, tunnel_at))
		_check("没救人：没有光门和掉头虫洞", finale.find_children("*", "Wormhole", true, false).is_empty())
		_deaths = 0
		await _autopilot(ROUTE_NONE)
		_check("一个都没救：自己跑到逃离点，正常结局", await _until(_in_ending, 200) and Game.ending == &"main")
		_check("跑过点灯的人之后：加速带一路铺到结尾", _strip_total > 0 and _strip_lit == _strip_total,
				"%d / %d 段" % [_strip_lit, _strip_total])
		_check("一个都没救：一路没死", _deaths == 0, "死了 %d 次，噬光者最近 %.0f px" % [_deaths, _min_gap])
		print("NOHELP_MIN_GAP %.0f" % _min_gap)

		# 全救了：一路有人帮，最后从科学家的虫洞掉头撞碎噬光者。
		_rescue_all()
		_check("打开终章（全救了）", await _open())
		_deaths = 0
		_helps.clear()
		await _autopilot(ROUTE_ALL)
		_check("全救了：掉头撞碎噬光者，隐藏结局", await _until(_in_ending, 200) and Game.ending == &"hidden")
		# S 形迷宫会吃掉一段冲刺距离：掉头撞噬光者这一趟允许死 1 次（死了从检查点重来接着冲）。
		_check("全救了：一路没死（迷宫允许 1 次）", _deaths <= 1, "死了 %d 次" % _deaths)
		var roles := [&"watchman", &"doctor", &"clockmaker", &"painter", &"gardener", &"musician", &"miner", &"scientist"]
		_check("一路上大家都帮了忙", roles.all(func(r: StringName) -> bool: return _helps.has(r)), "%s" % [_helps])
		return true

	## 直接打开终章场景，等小星出生完（从开头出发时会被锁住）。
	func _open() -> bool:
		Game.flow = Game.Flow.PLAYING
		Save.checkpoint = ""
		get_tree().change_scene_to_file(Game.FINALE_SCENE)
		return await _until(func() -> bool:
			var f := _finale()
			return f != null and f.player != null and f.player.state != Player.State.SPAWN)

	## 小星自己跑：一直按左，上下朝前面最近的路点那一行靠，直到进结局或超时。死了重来就接着跑。
	var _wp := 0

	func _autopilot(route: Array, max_seconds := 60.0) -> void:
		_min_gap = 99999.0
		Input.action_press("move_left")
		var finale: Finale = null
		var points: Array[Vector2] = []
		for i in int(max_seconds * 60.0):
			await get_tree().physics_frame
			if Game.flow == Game.Flow.ENDING:
				break
			if _finale() == null:
				continue
			if not is_instance_valid(finale) or _finale() != finale:
				finale = _finale()
				points = _route(finale, route)
				_wp = 0
			var boss := finale.boss
			if boss != null and boss.state == Boss.State.CHASE:
				_min_gap = minf(_min_gap, boss.gap())
			if _strip_total > 0:
				var lit := 0
				for strip in _strips(finale):
					if strip.deployed:
						lit += 1
				_strip_lit = maxi(_strip_lit, lit)
			var p := finale.player
			if p.state != Player.State.ACTIVE:
				_steer(0)
				continue
			while _wp + 1 < points.size() and p.global_position.distance_to(points[_wp]) < 44.0:
				_wp += 1
			var target := points[mini(_wp, points.size() - 1)]
			var want := clampf((target.y - p.global_position.y) * 3.0, -350.0, 350.0)
			_steer(-1 if p.velocity.y > want + 25.0 else (1 if p.velocity.y < want - 25.0 else 0))
			_steer_x(target.x - p.global_position.x)
		_steer(0)
		_steer_x(0.0)
		Input.action_release("move_left")

	## 水平方向：和垂直分开控制，迷宫折返时才走得回去。
	func _steer_x(dx: float) -> void:
		if dx < -8.0:
			Input.action_press("move_left")
			Input.action_release("move_right")
		elif dx > 8.0:
			Input.action_press("move_right")
			Input.action_release("move_left")
		else:
			Input.action_release("move_left")
			Input.action_release("move_right")

	## dir：-1 按上，1 按下，0 都松开。
	func _steer(dir: int) -> void:
		if dir < 0:
			Input.action_press("move_up")
		else:
			Input.action_release("move_up")
		if dir > 0:
			Input.action_press("move_down")
		else:
			Input.action_release("move_down")

	## 路线换成全局坐标（一格 32 px，取格子中心）。
	func _route(finale: Finale, route: Array) -> Array[Vector2]:
		var out: Array[Vector2] = []
		for step: Array in route:
			out.append(_section(finale, step[0]).global_position + Vector2((step[1] + 0.5) * 32.0, (step[2] + 0.5) * 32.0))
		return out

	func _section(finale: Finale, id: String) -> Node2D:
		if id == "Intro" or id == "Outro":
			return finale.get_node(id) as Node2D
		for lane in _lanes(finale):
			if String(lane.chapter_id) == id:
				return lane.get_node(^"ChaseLane") as Node2D
		return null

	func _lanes(finale: Finale) -> Array[Chapter]:
		var out: Array[Chapter] = []
		for child in finale.get_children():
			if child is Chapter:
				out.append(child)
		return out

	func _help_points(root: Node) -> Array[HelpPoint]:
		var out: Array[HelpPoint] = []
		for node in root.find_children("*", "HelpPoint", true, false):
			if not node.is_queued_for_deletion():
				out.append(node)
		return out

	## 赛道上的加速带（园丁的花不算，那是他自己种的）。
	func _strips(root: Node) -> Array[AccelStrip]:
		var out: Array[AccelStrip] = []
		for node in root.find_children("*", "AccelStrip", true, false):
			var strip := node as AccelStrip
			if strip != null and not strip.flowers and not strip.is_queued_for_deletion():
				out.append(strip)
		return out

	func _help(finale: Finale, role: String) -> HelpPoint:
		for help in _help_points(finale):
			if help.role == role:
				return help
		return null

	## 章节场景和终章场景里一共有几个帮助点。
	func _help_total() -> int:
		var n := 0
		var paths: Array = Game.chapters.map(func(c: Array) -> String: return c[1])
		paths.append(Game.FINALE_SCENE)
		for path: String in paths:
			var root := (load(path) as PackedScene).instantiate()
			n += root.find_children("*", "HelpPoint", true, false).size()
			root.free()
		return n

	func _npc_count() -> int:
		var n := 0
		for chapter: Array in Game.chapters:
			var root := (load(chapter[1]) as PackedScene).instantiate()
			n += root.find_children("*", "Npc", true, false).size()
			root.free()
		return n

	## 把章节表里各章的人都记成已救。
	func _rescue_all() -> void:
		Save.clear()
		for chapter: Array in Game.chapters:
			var root := (load(chapter[1]) as PackedScene).instantiate()
			for npc: Npc in root.find_children("*", "Npc", true, false):
				Save.rescued[Save.id_of(npc)] = StringName(npc.role)
			root.free()

	func _wall_at(root: Node, point: Vector2) -> bool:
		for walls: TileMapLayer in root.find_children("*", "TileMapLayer", true, false):
			if walls.get_cell_source_id(walls.local_to_map(walls.to_local(point))) != -1:
				return true
		return false
