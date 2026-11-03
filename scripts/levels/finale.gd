class_name Finale
extends Node2D
## 终章（docs/state-machines.md 第 13 节）。开头（Intro）里噬光者醒来；然后按章节倒序接上各章的回程赛道，
## 每段的 Entry 对齐上一段的 Exit；最后接上结尾（Outro）。跑到逃离点是正常结局。所有人都已救时，
## 科学家在结尾放下掉头的虫洞，以阶段 5 撞碎噬光者是隐藏结局。
## 检查点是每段赛道和结尾的 Entry：复活时小星从那里带着初速出来，噬光者在身后 boss_gap_start 处重新出现。

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const BOSS_SCENE := preload("res://scenes/entities/boss.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
## 镜头上下多留的距离：赛道比屏幕矮时，小星也能在屏幕中间。
const CAMERA_PAD := 240.0

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
