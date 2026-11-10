extends Node
## 生成测试关和终章。在工程目录运行（要以场景方式运行，脚本里用到的 Save、Game 单例才存在）：
##   godot --headless --path . res://tools/build_test_levels.tscn
## 地形读 tools/ 下的文本地图。data/tiles.tres 不存在时才生成；
## 场景每次覆盖，所以测试关和终章的地形改文本文件，不要在编辑器里改。
##
## 图例（一格 32 px）：
##   @ 边界（不可撞碎）  # 墙  . 空地  S 出生点
##   C 裂纹墙  P 软垫  V 影藤  H 栅栏  I 铁门  E 出口  > < ^ v 加速带（箭头 = 方向）：相连的同种格子合成一个，大小取外接矩形
##   - | 玻璃（横、竖，相连的合成一块）  / \ 斜 45° 的玻璃，一格一块，正好封住一个拐角
##   小人（一格一个）：n 普通人  w 守夜人  g 园丁  d 医生（照不到，等邮差）  a 画家  G 向导  m 矿工
##     L 锁匠  M 邮差（藏着）  p 乐手  q 听众（每个 p 和离它最近的 q 结伴）  c 钟表匠  Z 科学家（藏着）
##   * 小星星  K 检查点  A B 虫洞两端（每张图一对）  + 流星  = 黑洞（P2）
##   ' 路标：一点冷白色的小光点，只用来引路（教学关铺路用）
## 回程赛道（*_lane.txt，生成在关卡区下面，从右往左跑）：
##   R 进入点（最右一列，记在格子右边缘）  X 离开点（最左一列，记在格子左边缘），两个在同一行
##   小人的字母 = 帮助点，指向关卡区里同职业的那个人
##   l 路灯（守夜人的）  f 花（园丁的加速带，朝左，相连的合成一条）  O o 光门的入口和出口（画家的）
##   T 隧道（先铺成墙，矿工已救时打开，相连的合成一条）
## 终章开头 finale_intro.txt：S 出生点  Q 噬光者出现的地方  X 离开点
## 终章结尾 finale_outro.txt：R 进入点  E 逃离点  Z 科学家（所有人都已救才出现）  A B 他放下的掉头虫洞（从 B 朝右出来）

## 地图的种类。小人的字母在关卡区是小人，在赛道和终章结尾是帮助点；终章结尾的 E 是逃离点。
enum Kind { LEVEL, LANE, INTRO, OUTRO }

const TILE := 32
const TILES_PATH := "res://data/tiles.tres"
const CHAPTER_SCRIPT := "res://scripts/levels/chapter.gd"
const FINALE_SCRIPT := "res://scripts/levels/finale.gd"
## 关卡区的地图、场景、根节点名、chapter_id、是否加暗处、回程赛道的地图。
## 关卡区不摆加速带：阶段 4（撞碎裂纹墙）靠长直道就够，阶段 5 只在终章赛道上出现。
const LEVELS := [
	["res://tools/ch0_map.txt", "res://scenes/levels/ch0_fall.tscn", "Ch0Fall", &"ch0", true, "res://tools/ch0_lane.txt"],
	["res://tools/ch1_map.txt", "res://scenes/levels/ch1_vine.tscn", "Ch1Vine", &"ch1", true, "res://tools/ch1_lane.txt"],
	["res://tools/ch2_map.txt", "res://scenes/levels/ch2_mirror.tscn", "Ch2Mirror", &"ch2", true, "res://tools/ch2_lane.txt"],
	["res://tools/ch3_map.txt", "res://scenes/levels/ch3_crack.tscn", "Ch3Crack", &"ch3", true, "res://tools/ch3_lane.txt"],
	["res://tools/ch4_map.txt", "res://scenes/levels/ch4_pair.tscn", "Ch4Pair", &"ch4", true, "res://tools/ch4_lane.txt"],
	["res://tools/test_feel_map.txt", "res://scenes/levels/test_feel.tscn", "TestFeel", &"test_feel", false, "res://tools/test_feel_lane.txt"],
	["res://tools/test_light_map.txt", "res://scenes/levels/test_light.tscn", "TestLight", &"test_light", true, "res://tools/test_light_lane.txt"],
	["res://tools/test_enemy_map.txt", "res://scenes/levels/test_enemy.tscn", "TestEnemy", &"test_enemy", false, "res://tools/test_feel_lane.txt"],
]
## 每章的整体色调：郊区冷、城市暖。回程赛道反过来。
const TINTS := {
	&"ch0": [Color(0.78, 0.86, 1.0), Color(1.14, 1.02, 0.86)],
	&"ch1": [Color(0.86, 0.92, 1.0), Color(1.10, 1.01, 0.88)],
	&"ch2": [Color(1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0)],
	&"ch3": [Color(1.06, 1.0, 0.92), Color(0.88, 0.93, 1.0)],
	&"ch4": [Color(1.14, 1.02, 0.86), Color(0.78, 0.86, 1.0)],
}
const FINALE_INTRO := "res://tools/finale_intro.txt"
const FINALE_OUTRO := "res://tools/finale_outro.txt"
## 赛道和终章结尾放在上一块下面，中间空几行。
const AREA_GAP := 4
## 赛道加速带推到多快：阶段 5（≥760）。只有回程赛道才摆加速带。
const STRIP_SPEED := 920.0
const STRIP_SCENE := "res://scenes/entities/accel_strip.tscn"
const MIRROR_SCENE := "res://scenes/entities/mirror.tscn"
const NPC_SCENE := "res://scenes/entities/npc.tscn"
const WORMHOLE_SCENE := "res://scenes/entities/wormhole.tscn"
const HELP_SCENE := "res://scenes/entities/help_point.tscn"
const LAMP_SCENE := "res://scenes/entities/lamp.tscn"
const TUNNEL_SCENE := "res://scenes/entities/tunnel.tscn"
const ESCAPE_SCENE := "res://scenes/entities/escape_point.tscn"
const SCENES := {
	"C": "res://scenes/entities/cracked_wall.tscn",
	"P": "res://scenes/entities/pad.tscn",
	"V": "res://scenes/entities/shadow_vine.tscn",
	"H": "res://scenes/entities/bars.tscn",
	"I": "res://scenes/entities/iron_door.tscn",
	"E": "res://scenes/entities/exit.tscn",
	"*": "res://scenes/entities/star_shard.tscn",
	"K": "res://scenes/entities/checkpoint.tscn",
	">": STRIP_SCENE, "<": STRIP_SCENE, "^": STRIP_SCENE, "v": STRIP_SCENE,
	"-": MIRROR_SCENE, "|": MIRROR_SCENE, "/": MIRROR_SCENE, "\\": MIRROR_SCENE,
	"'": "res://scenes/entities/breadcrumb.tscn",
	"+": "res://scenes/entities/meteor.tscn",
	"=": "res://scenes/entities/blackhole.tscn",
	"x": "res://scenes/entities/enemy.tscn",
}
## 小人的图例 → 职业。
const ROLES := {
	"n": "none", "w": "watchman", "g": "gardener", "d": "doctor", "a": "painter", "G": "guide", "m": "miner", "D": "doctor",
	"L": "locksmith", "M": "postman", "p": "musician", "q": "listener", "c": "clockmaker", "Z": "scientist",
}
## 标记点：字母 → [节点名, 记在格子的哪里（0 = 左边缘，0.5 = 中间，1 = 右边缘）]。
const MARKERS := {"S": ["PlayerStart", 0.5], "Q": ["BossStart", 0.5], "R": ["Entry", 1.0], "X": ["Exit", 0.0]}
## 赛道里挂在帮助点下面的东西 → 那个帮助点的职业。光门的两端 O、o 另外处理。
const PARTS := {"l": "watchman", "f": "gardener", "T": "miner"}
const STRIP_ANGLE := {">": 0.0, "v": PI / 2.0, "<": PI, "^": -PI / 2.0}
## 这些一格一个实体，不和相邻的同种格子合并。
const SINGLE := "/\\*Kl+='x"

func _ready() -> void:
	var tiles := _load_or_make_tileset()
	var err := OK
	for level in LEVELS:
		err = _report(level[1], _build_chapter(tiles, level), err)
	err = _report(Game.FINALE_SCENE, _build_finale(tiles), err)
	get_tree().quit(err)

func _report(path: String, e: Error, err: Error) -> Error:
	print("BUILD %s %s" % [path, "OK" if e == OK else "FAILED %d" % e])
	return e if e != OK else err

## 图块集每次构建都重新生成（图集由 tools/tile_art.py 画）。图源编号见 scripts/levels/wall_tiles.gd：
## 风格 s 的墙 = 3s、边界墙 = 3s + 1、地面 = 3s + 2。tests/test_collisions 直接用图源 0、1 的 (0, 0)。
func _load_or_make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, Layers.WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_occlusion_layer()
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "unbreakable")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	for style: String in WallTiles.STYLES:
		_add_wall_atlas(ts, "res://assets/art/level/walls_%s.png" % style, false)
		_add_wall_atlas(ts, "res://assets/art/level/walls_unbreakable_%s.png" % style, true)
		_add_floor_atlas(ts, "res://assets/art/level/floors_%s.png" % style)
	ResourceSaver.save(ts, TILES_PATH, ResourceSaver.FLAG_CHANGE_PATH)
	return ts

## 墙图集：每格整格碰撞；遮光体按列（掩码）在挨着空地的边往里缩，墙沿能被照亮。
func _add_wall_atlas(ts: TileSet, path: String, unbreakable: bool) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = load(path) as Texture2D
	source.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(source)
	var h := TILE * 0.5
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for v in WallTiles.VARIANTS:
		for m in WallTiles.MASKS:
			var at := Vector2i(m, v)
			source.create_tile(at)
			var data := source.get_tile_data(at, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
			data.set_occluder(0, WallTiles.occluder_for(m, TILE))
			data.set_custom_data("unbreakable", unbreakable)

## 地面图集：只贴图，不碰撞、不挡光。
func _add_floor_atlas(ts: TileSet, path: String) -> void:
	var source := TileSetAtlasSource.new()
	source.texture = load(path) as Texture2D
	source.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(source)
	for v in WallTiles.VARIANTS:
		for m in WallTiles.MASKS:
			source.create_tile(Vector2i(m, v))

## 每章用哪种墙和地面：郊区（ch0–ch2）粗石块 + 石板地，城市（ch3、ch4）砖墙 + 方砖路。
const STYLE_BY_CHAPTER := {&"ch0": 0, &"ch1": 0, &"ch2": 0, &"ch3": 1, &"ch4": 1}

## 章节场景（docs/level-data-format.md 第 2 节）：Level 是关卡区，ChaseLane 是回程赛道，生成在关卡区下面。
func _build_chapter(tiles: TileSet, spec: Array) -> Error:
	var root := Node2D.new()
	root.name = spec[2]
	root.set_script(load(CHAPTER_SCRIPT))
	root.set("chapter_id", spec[3])
	root.set("dark", spec[4])
	var tint: Variant = TINTS.get(spec[3])
	if tint != null:
		root.set("tint", tint[0])
		root.set("lane_tint", tint[1])
	var level := _area(root, root, "Level")
	var style: int = STYLE_BY_CHAPTER.get(spec[3], 0)
	var rows := _build_area(root, level, tiles, spec[0], Kind.LEVEL, {}, _tier_for(spec[3]), style)
	# 赛道里的帮助点按职业找关卡区里的人。
	var npcs := {}
	for node in level.get_node(^"Entities").get_children():
		if node is Npc:
			npcs[node.role] = node
	var lane := _area(root, root, "ChaseLane")
	lane.position = Vector2(0, (rows + AREA_GAP) * TILE)
	_build_area(root, lane, tiles, spec[5], Kind.LANE, npcs, 1, style)
	return _save(root, spec[1])

## 章节 id → 影鬼的等级（序章最轻，第五章最狠）。测试关没有对应章节，就按 1 算。
func _tier_for(id: StringName) -> int:
	for i in Game.chapters.size():
		if Game.chapters[i][0] == id:
			return mini(i + 1, 5)
	return 1

## 终章：开头和结尾两块，中间的赛道运行时按章节表接上（scripts/levels/finale.gd）。
func _build_finale(tiles: TileSet) -> Error:
	var root := Node2D.new()
	root.name = "Finale"
	root.set_script(load(FINALE_SCRIPT))
	var intro := _area(root, root, "Intro")
	# 终章从城市（ch4 的赛道）一路跑回郊区（ch0 的赛道）：开头是城市，结尾是郊区。
	var rows := _build_area(root, intro, tiles, FINALE_INTRO, Kind.INTRO, {}, 1, 1)
	# 结尾运行时挪到最后一段赛道后面；这里先放在开头下面，编辑器里看得清。
	var outro := _area(root, root, "Outro")
	outro.position = Vector2(0, (rows + AREA_GAP) * TILE)
	_build_area(root, outro, tiles, FINALE_OUTRO, Kind.OUTRO, {}, 1, 0)
	return _save(root, Game.FINALE_SCENE)

func _save(root: Node, path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var scene := PackedScene.new()
	var err := scene.pack(root)
	if err == OK:
		err = ResourceSaver.save(scene, path)
	root.free()
	return err

func _area(root: Node, parent: Node, area_name: String) -> Node2D:
	var area := Node2D.new()
	area.name = area_name
	_add(root, parent, area)
	return area

## 按文本地图在 area 下铺墙（Walls）、摆实体（Entities）、放标记点。npcs 是关卡区里的人（职业 → 节点），
## 赛道里的帮助点指向他们。返回地图有几行。
func _build_area(root: Node, area: Node2D, tiles: TileSet, map_path: String, kind: Kind, npcs := {}, tier := 1, style := 0) -> int:
	# 地面层垫在墙下面：每个不是墙的格子铺一块，挨着墙的边带接触阴影。
	var ground := TileMapLayer.new()
	ground.name = "Floor"
	ground.tile_set = tiles
	_add(root, area, ground)
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = tiles
	_add(root, area, walls)
	var entities := Node2D.new()
	entities.name = "Entities"
	_add(root, area, entities)
	var marks := {}
	var ends := {}
	var rows := FileAccess.get_file_as_string(map_path).strip_edges().split("\n")
	for y in rows.size():
		for x in rows[y].length():
			var cell := Vector2i(x, y)
			var ch := rows[y][x]
			match ch:
				"@":
					walls.set_cell(cell, WallTiles.wall_source(style, true), Vector2i.ZERO)
				"#":
					walls.set_cell(cell, WallTiles.wall_source(style, false), Vector2i.ZERO)
				".":
					pass
				"A", "B", "O", "o":
					ends[ch] = _center(Rect2i(cell, Vector2i.ONE))
				_:
					if ch == "T":
						# 隧道先铺成墙，矿工已救时才打开。
						walls.set_cell(cell, WallTiles.wall_source(style, false), Vector2i.ZERO)
					if MARKERS.has(ch):
						_add_marker(root, area, ch, cell)
					else:
						marks[cell] = ch
	_dress(walls, ground, rows, style)
	var helpers := {}
	var parts := []
	var seen := {}
	var pairs := {"p": [], "q": []}
	for cell: Vector2i in marks:
		if seen.has(cell):
			continue
		var ch: String = marks[cell]
		var rect := Rect2i(cell, Vector2i.ONE) if ch in SINGLE or ROLES.has(ch) else _flood(marks, cell, seen)
		seen[cell] = true
		if kind == Kind.LANE and PARTS.has(ch):
			parts.append([ch, rect])
			continue
		var node := _place(root, entities, ch, rect, kind, npcs, tier, _checkpoint_name(marks, cell) if ch == "K" else "")
		if node is HelpPoint:
			helpers[node.role] = node
		elif node != null and pairs.has(ch):
			pairs[ch].append(node)
	_link_pairs(pairs["p"], pairs["q"])
	for part in parts:
		_place_part(root, helpers, part[0], part[1])
	match kind:
		Kind.LEVEL:
			if ends.has("A") and ends.has("B"):
				_add_wormhole(root, entities, ends["A"], ends["B"])
		Kind.LANE:
			if ends.has("O") and ends.has("o"):
				# 画家的光门：一条单向的捷径，出来时方向不变。
				var painter: Node2D = helpers.get("painter")
				if painter == null:
					push_error("%s：有光门但没有画家" % map_path)
				else:
					var door := _add_wormhole(root, painter, ends["O"] - painter.position, ends["o"] - painter.position)
					door.set("two_way", false)
		Kind.OUTRO:
			if ends.has("A") and ends.has("B"):
				# 科学家的虫洞：从 B 朝右（来路）出来，掉头撞向噬光者。
				var scientist: Node2D = helpers.get("scientist")
				if scientist == null:
					push_error("%s：有掉头虫洞但没有科学家" % map_path)
				else:
					var worm := _add_wormhole(root, scientist, ends["A"] - scientist.position, ends["B"] - scientist.position)
					worm.set("two_way", false)
					worm.set("keep_direction", false)
					worm.set("charge", true)
	return rows.size()

## 墙按四邻换成带墙沿的那一格，空地铺地面。地图外面算墙（不画墙沿、不铺地）。
func _dress(walls: TileMapLayer, ground: TileMapLayer, rows: PackedStringArray, style: int) -> void:
	for y in rows.size():
		for x in rows[y].length():
			var cell := Vector2i(x, y)
			var src := walls.get_cell_source_id(cell)
			if src != -1:
				var m := 0
				for d: Array in WallTiles.DIRS:
					var nb: Vector2i = cell + d[1]
					var inside := nb.y >= 0 and nb.y < rows.size() and nb.x >= 0 and nb.x < rows[nb.y].length()
					if inside and not WallTiles.is_wall(walls, nb):
						m |= d[0]
				walls.set_cell(cell, src, Vector2i(m, WallTiles.variant(cell)))
			elif rows[y][x] != " ":
				ground.set_cell(cell, WallTiles.floor_source(style), Vector2i(WallTiles.floor_mask(walls, cell), WallTiles.variant(cell)))

func _add(root: Node, parent: Node, node: Node) -> void:
	parent.add_child(node, true)
	node.owner = root

func _add_marker(root: Node, area: Node, ch: String, cell: Vector2i) -> void:
	var marker := Marker2D.new()
	marker.name = MARKERS[ch][0]
	marker.position = Vector2((cell.x + MARKERS[ch][1]) * TILE, (cell.y + 0.5) * TILE)
	_add(root, area, marker)

func _center(rect: Rect2i) -> Vector2:
	return Vector2(rect.position * TILE) + Vector2(rect.size * TILE) * 0.5

## 带上实例状态，pack() 才只保存改过的属性，和编辑器存出来的一样。
func _instance(path: String) -> Node2D:
	return (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node2D

## 检查点按从左到右编号：Checkpoint、Checkpoint2……存档记的是节点路径，
## 后加的检查点不管摆在哪一行，都不会把原来那个的名字（玩家存档里的 id）顶掉——只要它在原来那个右边。
func _checkpoint_name(marks: Dictionary, cell: Vector2i) -> String:
	var order := 1
	for c: Vector2i in marks:
		if marks[c] == "K" and (c.x < cell.x or (c.x == cell.x and c.y < cell.y)):
			order += 1
	return "Checkpoint" if order == 1 else "Checkpoint%d" % order

func _place(root: Node, parent: Node, ch: String, rect: Rect2i, kind: Kind, npcs: Dictionary, tier := 1, node_name := "") -> Node2D:
	if ROLES.has(ch):
		if kind == Kind.LEVEL:
			return _place_npc(root, parent, ch, rect)
		return _place_help(root, parent, ch, rect, kind, npcs)
	if not SCENES.has(ch):
		push_error("未知图例 [%s] 码 %d，位置 %s" % [ch, ch.unicode_at(0), rect.position])
		return null
	var node := _instance(ESCAPE_SCENE if kind == Kind.OUTRO and ch == "E" else SCENES[ch])
	var size := Vector2(rect.size * TILE)
	match ch:
		">", "<", "^", "v":
			node.rotation = STRIP_ANGLE[ch]
			node.set("size", size if ch == ">" or ch == "<" else Vector2(size.y, size.x))
			node.set("target_speed", STRIP_SPEED)
		"-":
			node.set("length", size.x)
		"|":
			node.rotation = PI / 2.0
			node.set("length", size.y)
		"/", "\\":
			# 从格子一角斜到对角，两头各伸进墙里 4 px，小星挤不过去，光能拐过去。
			node.rotation = -PI / 4.0 if ch == "/" else PI / 4.0
			node.set("length", TILE * sqrt(2.0) + 8.0)
		"C", "P", "V", "H", "I", "E":
			node.set("size", size)
		"x":
			# 第几章的影鬼：越往后越狠（瞄准更快、冷却更短，第三章起双发）
			node.set("tier", tier)
	node.position = _center(rect)
	if node_name != "":
		node.name = node_name
	_add(root, parent, node)
	return node

## 小人：职业由图例决定。医生照不到、等邮差；邮差和科学家是藏着的人。
func _place_npc(root: Node, parent: Node, ch: String, rect: Rect2i) -> Node2D:
	var node := _instance(NPC_SCENE)
	node.set("role", ROLES[ch])
	if ch == "d":
		node.set("mail", true)
	if ch == "M" or ch == "Z":
		node.set("secret", true)
	node.position = _center(rect)
	_add(root, parent, node)
	return node

## 帮助点：赛道里指向关卡区里同职业的那个人；终章结尾的科学家要所有人都已救才出现。
func _place_help(root: Node, parent: Node, ch: String, rect: Rect2i, kind: Kind, npcs: Dictionary) -> Node2D:
	var role: String = ROLES[ch]
	var node := _instance(HELP_SCENE)
	node.name = role.capitalize()
	node.set("role", role)
	node.position = _center(rect)
	_add(root, parent, node)
	if kind == Kind.OUTRO:
		node.set("everyone", true)
	elif npcs.has(role):
		node.set("npc", node.get_path_to(npcs[role]))
	else:
		push_error("赛道里的 %s 在关卡区里找不到同职业的人" % role)
	return node

## 帮助点的子节点：路灯、花、隧道，位置换算成相对帮助点。
func _place_part(root: Node, helpers: Dictionary, ch: String, rect: Rect2i) -> void:
	var help: Node2D = helpers.get(PARTS[ch])
	if help == null:
		push_error("%s 没有对应的帮助点（%s），位置 %s" % [ch, PARTS[ch], rect.position])
		return
	var node: Node2D
	match ch:
		"l":
			node = _instance(LAMP_SCENE)
		"f":
			node = _instance(STRIP_SCENE)
			node.rotation = PI
			node.set("size", Vector2(rect.size * TILE))
			node.set("flowers", true)
		"T":
			node = _instance(TUNNEL_SCENE)
			node.set("size", Vector2(rect.size * TILE))
	node.position = _center(rect) - help.position
	_add(root, help, node)

## 每个 p 和离它最近的 q 结伴，partner 设在 p 身上。
func _link_pairs(ps: Array, qs: Array) -> void:
	for p: Node2D in ps:
		var best: Node2D = null
		for q: Node2D in qs:
			if best == null or p.position.distance_to(q.position) < p.position.distance_to(best.position):
				best = q
		if best != null:
			p.set("partner", p.get_path_to(best))

## a、b 是 parent 里的坐标。
func _add_wormhole(root: Node, parent: Node, a: Vector2, b: Vector2) -> Node2D:
	var worm := _instance(WORMHOLE_SCENE)
	worm.position = (a + b) * 0.5
	_add(root, parent, worm)
	# 两端是虫洞场景里的子节点，打开"可编辑子节点"才会把改过的位置存进关卡。
	root.set_editable_instance(worm, true)
	(worm.get_node("A") as Node2D).position = a - worm.position
	(worm.get_node("B") as Node2D).position = b - worm.position
	return worm

func _flood(marks: Dictionary, start: Vector2i, seen: Dictionary) -> Rect2i:
	var ch: String = marks[start]
	var rect := Rect2i(start, Vector2i.ONE)
	var stack: Array[Vector2i] = [start]
	seen[start] = true
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		rect = rect.merge(Rect2i(c, Vector2i.ONE))
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nb := c + d
			if not seen.has(nb) and marks.get(nb, "") == ch:
				seen[nb] = true
				stack.append(nb)
	return rect
