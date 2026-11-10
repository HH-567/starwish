class_name Finale
extends Node2D
## 终章（docs/state-machines.md 第 13 节）。开头（Intro）里噬光者醒来；然后按章节倒序接上各章的回程赛道，
## 每段的 Entry 对齐上一段的 Exit；最后接上结尾（Outro）。跑到逃离点是正常结局。所有人都已救时，
## 科学家在结尾放下掉头的虫洞，以阶段 5 撞碎噬光者是隐藏结局。
## 检查点是每段赛道和结尾的 Entry：复活时小星从那里带着初速出来，噬光者在身后 boss_gap_start 处重新出现。

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const BOSS_SCENE := preload("res://scenes/entities/boss.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const LIGHTER_SCENE := preload("res://scenes/entities/road_lighter.tscn")
## 镜头上下多留的距离：赛道比屏幕矮时，小星也能在屏幕中间。
const CAMERA_PAD := 240.0
## 铺路演出时镜头往赛道前方滑多远。
const SWEEP_PX := 1500.0
## 一段加速带和下一段之间隔多久铺（真实时间，秒）。
const DEPLOY_GAP := 0.07
## 终章噬光者速度：迷宫会逼玩家转向掉速，全球 420 会把每次转弯都变成送死，压到 395。
const BOSS_SPEED_CHASE := 395.0

## 存档 id 的前缀：开头和结尾里的节点 id 是 "finale/…"。
var chapter_id := &"finale"
## 检查点：各段赛道和结尾的 Entry，按跑的顺序。
var entries: Array[Node2D] = []
var player: Player
var boss: Boss

## 跑过的最后一个检查点在 entries 里的位置，-1 = 还在开头。
var _reached := -1
## 从开头出发：噬光者登场时锁住小星。
var _from_start := false

func _init() -> void:
	add_to_group(&"chapter")

func _ready() -> void:
	if Game.flow == Game.Flow.PLAYING:
		# 直接运行这个场景（F6、测试）时没经过 Game 加载。
		Game.flow = Game.Flow.CHASE
	Audio.set_ducked(false)
	var floors := _stitch()
	Lighting.add_darkness(self, floors)
	_spawn()
	add_child(HUD_SCENE.instantiate())
	var bounds := floors[0]
	for rect in floors:
		bounds = bounds.merge(rect)
	bounds = bounds.grow_individual(0.0, CAMERA_PAD, 0.0, CAMERA_PAD)
	var cam := player.get_node(^"Camera") as Camera2D
	cam.limit_left = int(bounds.position.x)
	cam.limit_top = int(bounds.position.y)
	cam.limit_right = int(bounds.end.x)
	cam.limit_bottom = int(bounds.end.y)
	cam.reset_smoothing()
	Game.boss_state_changed.connect(_on_boss_state_changed)
	Game.road_light.connect(_on_road_light)
	_setup_tint()
	if Game.debug_flat_maze:
		_flatten_outro()
	Game.tuning.boss_speed = BOSS_SPEED_CHASE
	# 赛道一开始是暗的：加速带全收起来，等点灯的人来铺。
	if _reached < 0:
		for strip in _strips():
			strip.undeploy()
		_add_lighter()
	else:
		# 从检查点续跑：路早就点着了，直接铺好，不再演一遍。
		for strip in _strips():
			strip.deploy()

## 终章的冷暖渐变：从城里（暖）一路跑回郊外（冷）。
const TINT_CITY := Color(1.16, 1.02, 0.84)
const TINT_SUBURB := Color(0.74, 0.84, 1.04)

var _tint_items: Array[CanvasItem] = []
var _tint_shade: CanvasModulate
var _tint_from := 0.0
var _tint_to := 0.0

## 把要染色的墙和实体收起来，再记下"从哪跑到哪"的横坐标范围。
func _setup_tint() -> void:
	for child in get_children():
		if child is CanvasModulate:
			_tint_shade = child as CanvasModulate
	_tint_items.clear()
	for area_name: String in ["Intro", "Outro"]:
		var area := get_node_or_null(NodePath(area_name)) as Node2D
		if area != null:
			_collect_tint_items(area)
	for child in get_children():
		if child is Chapter:
			var area := (child as Chapter).get_node_or_null(^"ChaseLane") as Node2D
			if area != null:
				_collect_tint_items(area)
	var intro := $Intro as Node2D
	var outro := $Outro as Node2D
	_tint_from = (intro.get_node(^"Exit") as Node2D).global_position.x
	_tint_to = Chapter.walls_rect(outro.get_node(^"Walls") as TileMapLayer).position.x
	if _tint_to >= _tint_from:
		_tint_from = _tint_to - 1.0

func _collect_tint_items(area: Node2D) -> void:
	var ground := area.get_node_or_null(^"Floor") as TileMapLayer
	if ground != null:
		_tint_items.append(ground)
	var walls := area.get_node_or_null(^"Walls") as TileMapLayer
	if walls != null:
		_tint_items.append(walls)
	var entities := area.get_node_or_null(^"Entities") as Node2D
	if entities != null:
		_tint_items.append(entities)

## 按小星跑过的横向距离插值：城里暖、越跑越冷。
func _update_tint() -> void:
	if _tint_items.is_empty() or player == null:
		return
	var span := _tint_from - _tint_to
	var k := clampf((_tint_from - player.global_position.x) / maxf(span, 1.0), 0.0, 1.0)
	var c := TINT_CITY.lerp(TINT_SUBURB, k)
	for item in _tint_items:
		if is_instance_valid(item):
			item.modulate = c
	if _tint_shade != null:
		_tint_shade.color = Game.tuning.ambient * c

func _process(_delta: float) -> void:
	_update_tint()

## 点灯的人站在开头那段出口，小星跑过去他就把路点着。

## 测试用：把结尾那一段的内部墙抹平（只留最外圈边框），
## 这样 test_finale 只验追逐/加速带/结局分支，迷宫本身交给 tools/probe_maze 验。
func _flatten_outro() -> void:
	var outro := $Outro as Node2D
	if outro == null:
		return
	var walls := outro.get_node_or_null(^"Walls") as TileMapLayer
	if walls == null:
		return
	var used := walls.get_used_rect()
	for cell in walls.get_used_cells():
		var local := cell - used.position
		var at_edge := local.x <= 0 or local.y <= 0 or local.x >= used.size.x - 1 or local.y >= used.size.y - 1
		if not at_edge:
			walls.erase_cell(cell)
	walls.update_internals()

func _add_lighter() -> void:
	var exit := $Intro/Exit as Node2D
	var lighter := LIGHTER_SCENE.instantiate() as RoadLighter
	lighter.position = to_local(exit.global_position + Vector2(-80.0, 0.0))
	add_child(lighter)

## 赛道上所有加速带，按离小星的距离排好（先铺近的，再铺远的，一路铺到结尾）。
func _strips() -> Array[AccelStrip]:
	var out: Array[AccelStrip] = []
	for node in find_children("*", "AccelStrip", true, false):
		var strip := node as AccelStrip
		# 园丁的花是他自己种的，不归点灯的人管
		if strip != null and not strip.flowers:
			out.append(strip)
	out.sort_custom(func(a: AccelStrip, b: AccelStrip) -> bool: return a.global_position.x > b.global_position.x)
	return out

func _on_road_light(_pos: Vector2) -> void:
	await _light_road()

## 铺路演出：镜头往赛道前方滑过去，加速带一段一段亮起来，一路亮到结尾。
func _light_road() -> void:
	var cam := player.get_node(^"Camera") as Camera2D
	# 演出里小星不会被打断：给一段无敌和保护，跑掉的速度也由他自己控制
	player.hurt_left = maxf(player.hurt_left, 3.0)
	player.grace_left = maxf(player.grace_left, 3.0)
	cam.sweep(player.global_position + Vector2(-SWEEP_PX, 0.0), 1.3)
	for strip in _strips():
		if not is_instance_valid(strip):
			continue
		if strip.deployed:
			continue
		await get_tree().create_timer(DEPLOY_GAP, true, false, true).timeout
		if is_instance_valid(strip):
			strip.deploy()

func _physics_process(_delta: float) -> void:
	if _from_start and boss.state == Boss.State.EMERGE and player.state == Player.State.ACTIVE:
		# 噬光者登场时小星动不了。
		player.lock(true)
	if player.state != Player.State.ACTIVE:
		return
	# 赛道从右往左跑：跑到某段 Entry 的左边，就把它记成检查点。
	while _reached + 1 < entries.size() and player.global_position.x < entries[_reached + 1].global_position.x:
		_reached += 1
		Save.checkpoint = Save.id_of(entries[_reached])
		Game.checkpoint_reached.emit(Save.checkpoint)

## 按章节倒序接上各章的回程赛道，再接上结尾。返回每一段墙的范围，用来铺地面、算镜头范围。
func _stitch() -> Array[Rect2]:
	var intro := $Intro as Node2D
	var outro := $Outro as Node2D
	var floors: Array[Rect2] = [Chapter.walls_rect(intro.get_node(^"Walls") as TileMapLayer)]
	var at := (intro.get_node(^"Exit") as Node2D).global_position
	for i in range(Game.chapters.size() - 1, -1, -1):
		var chapter := (load(Game.chapters[i][1]) as PackedScene).instantiate() as Chapter
		chapter.prepare(Chapter.Mode.FINALE)
		var lane := chapter.get_node_or_null(^"ChaseLane") as Node2D
		if lane == null:
			chapter.free()
			continue
		var entry := lane.get_node(^"Entry") as Node2D
		# 先摆好再进场景树，物理体不用跟着挪。
		chapter.position = at - _offset(chapter, entry)
		add_child(chapter)
		entries.append(entry)
		floors.append(Chapter.walls_rect(lane.get_node(^"Walls") as TileMapLayer))
		at = (lane.get_node(^"Exit") as Node2D).global_position
	var outro_entry := outro.get_node(^"Entry") as Node2D
	outro.global_position = at - (outro_entry.global_position - outro.global_position)
	entries.append(outro_entry)
	floors.append(Chapter.walls_rect(outro.get_node(^"Walls") as TileMapLayer))
	return floors

## 存档里的检查点是某段的 Entry，就从那里带着初速出来，噬光者在身后出现；否则从开头出发，等噬光者登场。
func _spawn() -> void:
	var t := Game.tuning
	for i in entries.size():
		if Save.id_of(entries[i]) == Save.checkpoint:
			_reached = i
	boss = BOSS_SCENE.instantiate() as Boss
	add_child(boss)
	player = PLAYER_SCENE.instantiate() as Player
	if _reached < 0:
		_from_start = true
		player.position = to_local(($Intro/PlayerStart as Node2D).global_position)
		add_child(player)
		boss.emerge(player, ($Intro/BossStart as Node2D).global_position)
	else:
		var entry := entries[_reached]
		player.position = to_local(entry.global_position)
		player.velocity = Vector2.LEFT * t.chase_respawn_speed
		add_child(player)
		boss.emerge(player, entry.global_position + Vector2.RIGHT * t.boss_gap_start, Player.SPAWN_TIME)

func _on_boss_state_changed(state: int) -> void:
	match state:
		Boss.State.CHASE:
			player.lock(false)
		Boss.State.RETREAT, Boss.State.SHATTERED:
			# 结局演出：小星停在原地。
			player.lock(true)

## node 相对 root 的位置。root 还没进场景树，只能顺着父节点乘本地变换。
static func _offset(root: Node2D, node: Node2D) -> Vector2:
	var xf := Transform2D.IDENTITY
	var n: Node = node
	while n != root:
		xf = (n as Node2D).transform * xf
		n = n.get_parent()
	return xf.origin
