class_name Chapter
extends Node2D
## 章节场景的根（docs/level-data-format.md 第 2 节）。Level 是平时玩的关卡区，ChaseLane 是回程赛道，终章才用。
## Game 加载章节时，在加入场景树前调 prepare(mode) 删掉用不到的那棵；直接运行这个场景（F6、测试）时按普通模式。
## 普通模式：铺地面和暗处（dark 为真时），从当前检查点或 PlayerStart 生成小星，放 HUD，镜头范围 = Level/Walls。

enum Mode { NORMAL, FINALE }

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")

## 存档 id 的前缀，也是章节顺序表里的 id。
@export var chapter_id := &"test"
@export var dark := false
## 整体色调：郊区偏冷、城市偏暖。乘在墙砖和暗处环境光上。
@export var tint := Color.WHITE
## 回程赛道的色调：和关卡区反过来（城市 → 郊区）。
@export var lane_tint := Color.WHITE

var mode := Mode.NORMAL
var _prepared := false

func _init() -> void:
	# 子节点在 _ready 里算 save_id 时要找到章节根，所以在 _init 里就加组。
	add_to_group(&"chapter")

## 删掉这个模式用不到的子树：普通模式删 ChaseLane，终章模式删 Level。
## 赛道里的帮助点指向 Level 里的人，终章模式删 Level 之前先让它们记下那个人的 save_id 和职业。
func prepare(next: Mode) -> void:
	mode = next
	_prepared = true
	if next == Mode.FINALE:
		for help: HelpPoint in find_children("*", "HelpPoint", true, false):
			help.resolve()
	var unused := get_node_or_null(^"ChaseLane" if next == Mode.NORMAL else ^"Level")
	if unused != null:
		remove_child(unused)
		unused.free()

func _ready() -> void:
	if not _prepared:
		prepare(Mode.NORMAL)
	if mode == Mode.FINALE:
		return
	var level := $Level as Node2D
	var bounds := walls_rect(level.get_node(^"Walls") as TileMapLayer)
	_apply_tint(level, tint)
	var lane := get_node_or_null(^"ChaseLane") as Node2D
	if lane != null:
		_apply_tint(lane, lane_tint)
	if dark:
		Lighting.add_darkness(self, [bounds], Game.tuning.ambient * tint)
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = _spawn_point(level)
	add_child(player)
	add_child(HUD_SCENE.instantiate())
	var cam := player.get_node(^"Camera") as Camera2D
	cam.limit_left = int(bounds.position.x)
	cam.limit_top = int(bounds.position.y)
	cam.limit_right = int(bounds.end.x)
	cam.limit_bottom = int(bounds.end.y)
	cam.reset_smoothing()
	# 每章一段 BGM：文件没交付就静默跳过（Audio.play_bgm 自己判断）。
	Audio.play_bgm(chapter_id)
	# 死亡时压低的音乐，重新出生时抬回来。
	Audio.set_ducked(false)
	_apply_difficulty()

## 给一个区上色：墙砖和实体都乘上这个色调（实体里发光的会跟着偏，正好表达冷/暖）。
## 难度：永夜级在每只影鬼旁边多放一只，长夜级不动。
## 多出来的那只必须站在空地上：影鬼自己不吃碰撞，但摆进墙里就变成"卡在墙上的一只鬼"，
## 玩家打不到也绕不开。找不到空位就干脆不放（宁可少一只）。
func _apply_difficulty() -> void:
	if not Game.extra_enemies():
		return
	var level := get_node_or_null(^"Level") as Node2D
	var walls := level.get_node_or_null(^"Walls") as TileMapLayer if level != null else null
	for e in find_children("*", "Enemy", true, false):
		var src := e as Enemy
		if src == null:
			continue
		var at := _enemy_spot(src, walls)
		if is_nan(at.x):
			continue
		var clone := src.duplicate() as Enemy
		if clone == null:
			continue
		src.get_parent().add_child(clone)
		clone.global_position = at
		clone.add_to_group(&"enemy")

## 在影鬼旁边找一块能站的地方：整只（半径 + 余量）都不压墙、在地图范围内，
## 而且从原位过去是一条直线（不会隔着墙跳到别的走廊）。找不到返回 (NAN, NAN)。
func _enemy_spot(src: Enemy, walls: TileMapLayer) -> Vector2:
	if walls == null:
		return src.global_position + Vector2(0.0, 96.0)
	var from := walls.to_local(src.global_position)
	var radius := src.radius + 8.0
	var dirs: Array[Vector2] = [
		Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP,
		Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
		Vector2(1, -1).normalized(), Vector2(-1, -1).normalized(),
	]
	for dist: float in [96.0, 64.0]:
		for dir: Vector2 in dirs:
			var at := from + dir * dist
			if not _cell_free(walls, at, radius):
				continue
			if not _straight_free(walls, from, at):
				continue
			return walls.to_global(at)
	return Vector2(NAN, NAN)

## 这个点（含半径一圈）是不是全在空地上。
func _cell_free(walls: TileMapLayer, at: Vector2, radius: float) -> bool:
	var used := walls.get_used_rect()
	for i in 9:
		var p := at if i == 0 else at + Vector2.from_angle(TAU * float(i - 1) / 8.0) * radius
		var cell := walls.local_to_map(p)
		if not used.has_point(cell):
			return false
		if walls.get_cell_tile_data(cell) != null:
			return false
	return true

## 两点之间这条线上有没有墙。
func _straight_free(walls: TileMapLayer, from: Vector2, to: Vector2) -> bool:
	var steps := maxi(int(from.distance_to(to) / 8.0), 1)
	for i in steps + 1:
		var p := from.lerp(to, float(i) / float(steps))
		if walls.get_cell_tile_data(walls.local_to_map(p)) != null:
			return false
	return true

func _apply_tint(area: Node2D, c: Color) -> void:
	if area == null or c == Color.WHITE:
		return
	var walls := area.get_node_or_null(^"Walls") as TileMapLayer
	if walls != null:
		walls.modulate = c
	var ground := area.get_node_or_null(^"Floor") as TileMapLayer
	if ground != null:
		ground.modulate = c
	var entities := area.get_node_or_null(^"Entities") as Node2D
	if entities != null:
		entities.modulate = c.lerp(Color.WHITE, 0.35)

## 墙铺到的范围，全局坐标。章节的镜头范围和地面、终章每一段的地面都用它。
static func walls_rect(walls: TileMapLayer) -> Rect2:
	var used := walls.get_used_rect()
	var cell := Vector2(walls.tile_set.tile_size)
	return Rect2(walls.to_global(Vector2(used.position) * cell), Vector2(used.size) * cell)

## 存档里的检查点在这一章就从它出来，否则从 PlayerStart。
func _spawn_point(level: Node2D) -> Vector2:
	for node in get_tree().get_nodes_in_group(&"checkpoint"):
		var cp := node as Checkpoint
		if cp.save_id == Save.checkpoint and is_ancestor_of(cp):
			return to_local(cp.global_position)
	return to_local((level.get_node(^"PlayerStart") as Node2D).global_position)
