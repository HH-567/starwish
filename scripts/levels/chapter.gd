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
	if dark:
		Lighting.add_darkness(self, [bounds])
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
