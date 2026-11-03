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
##   * 小星星  K 检查点  A B 虫洞两端（每张图一对）
##   1–5 提示牌：走进来浮出一行字，文字见 scripts/data/hints.gd
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
const LEVELS := [
	["res://tools/ch0_map.txt", "res://scenes/levels/ch0_fall.tscn", "Ch0Fall", &"ch0", true, "res://tools/ch0_lane.txt"],
	["res://tools/test_feel_map.txt", "res://scenes/levels/test_feel.tscn", "TestFeel", &"test_feel", false, "res://tools/test_feel_lane.txt"],
	["res://tools/test_light_map.txt", "res://scenes/levels/test_light.tscn", "TestLight", &"test_light", true, "res://tools/test_light_lane.txt"],
]
const FINALE_INTRO := "res://tools/finale_intro.txt"
const FINALE_OUTRO := "res://tools/finale_outro.txt"
## 赛道和终章结尾放在上一块下面，中间空几行。
const AREA_GAP := 4
const STRIP_SCENE := "res://scenes/entities/accel_strip.tscn"
const MIRROR_SCENE := "res://scenes/entities/mirror.tscn"
const NPC_SCENE := "res://scenes/entities/npc.tscn"
const WORMHOLE_SCENE := "res://scenes/entities/wormhole.tscn"
const HELP_SCENE := "res://scenes/entities/help_point.tscn"
const HINT_SCENE := "res://scenes/entities/hint.tscn"
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
}
## 小人的图例 → 职业。
const ROLES := {
	"n": "none", "w": "watchman", "g": "gardener", "d": "doctor", "a": "painter", "G": "guide", "m": "miner",
	"L": "locksmith", "M": "postman", "p": "musician", "q": "listener", "c": "clockmaker", "Z": "scientist",
}
## 标记点：字母 → [节点名, 记在格子的哪里（0 = 左边缘，0.5 = 中间，1 = 右边缘）]。
const MARKERS := {"S": ["PlayerStart", 0.5], "Q": ["BossStart", 0.5], "R": ["Entry", 1.0], "X": ["Exit", 0.0]}
## 赛道里挂在帮助点下面的东西 → 那个帮助点的职业。光门的两端 O、o 另外处理。
const PARTS := {"l": "watchman", "f": "gardener", "T": "miner"}
const STRIP_ANGLE := {">": 0.0, "v": PI / 2.0, "<": PI, "^": -PI / 2.0}
## 这些一格一个实体，不和相邻的同种格子合并。
const SINGLE := "/\\*Kl12345"
## 地图里的数字 → 提示牌的文字 id（scripts/data/hints.gd）。
const HINTS := {"1": &"move", "2": &"light", "3": &"shard", "4": &"bump", "5": &"save"}

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

func _load_or_make_tileset() -> TileSet:
	if ResourceLoader.exists(TILES_PATH):
		return load(TILES_PATH)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, Layers.WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_occlusion_layer()
	ts.add_custom_data_layer()
	ts.set_custom_data_layer_name(0, "unbreakable")
	ts.set_custom_data_layer_type(0, TYPE_BOOL)
	_add_block(ts, Color("121a33"), Color("2b3a6b"), false)
	_add_block(ts, Color("070a14"), Color("1a2142"), true)
	ResourceSaver.save(ts, TILES_PATH, ResourceSaver.FLAG_CHANGE_PATH)
	return ts

## 加一个单格图块源：方形渐变贴图 + 整格碰撞 + 整格遮光。
func _add_block(ts: TileSet, inner: Color, edge: Color, unbreakable: bool) -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.78, 1.0])
	gradient.colors = PackedColorArray([inner, inner, edge])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_SQUARE
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = TILE
	tex.height = TILE
	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(source)
	source.create_tile(Vector2i.ZERO)
	var data := source.get_tile_data(Vector2i.ZERO, 0)
	var h := TILE * 0.5
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, square)
	var occluder := OccluderPolygon2D.new()
	occluder.polygon = square
	data.set_occluder(0, occluder)
	data.set_custom_data("unbreakable", unbreakable)

## 章节场景（docs/level-data-format.md 第 2 节）：Level 是关卡区，ChaseLane 是回程赛道，生成在关卡区下面。
func _build_chapter(tiles: TileSet, spec: Array) -> Error:
	var root := Node2D.new()
	root.name = spec[2]
	root.set_script(load(CHAPTER_SCRIPT))
	root.set("chapter_id", spec[3])
	root.set("dark", spec[4])
	var level := _area(root, root, "Level")
	var rows := _build_area(root, level, tiles, spec[0], Kind.LEVEL)
	# 赛道里的帮助点按职业找关卡区里的人。
	var npcs := {}
	for node in level.get_node(^"Entities").get_children():
		if node is Npc:
			npcs[node.role] = node
	var lane := _area(root, root, "ChaseLane")
	lane.position = Vector2(0, (rows + AREA_GAP) * TILE)
	_build_area(root, lane, tiles, spec[5], Kind.LANE, npcs)
	return _save(root, spec[1])

## 终章：开头和结尾两块，中间的赛道运行时按章节表接上（scripts/levels/finale.gd）。
func _build_finale(tiles: TileSet) -> Error:
	var root := Node2D.new()
	root.name = "Finale"
	root.set_script(load(FINALE_SCRIPT))
	var intro := _area(root, root, "Intro")
	var rows := _build_area(root, intro, tiles, FINALE_INTRO, Kind.INTRO)
	# 结尾运行时挪到最后一段赛道后面；这里先放在开头下面，编辑器里看得清。
	var outro := _area(root, root, "Outro")
	outro.position = Vector2(0, (rows + AREA_GAP) * TILE)
	_build_area(root, outro, tiles, FINALE_OUTRO, Kind.OUTRO)
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
func _build_area(root: Node, area: Node2D, tiles: TileSet, map_path: String, kind: Kind, npcs := {}) -> int:
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
					walls.set_cell(cell, 1, Vector2i.ZERO)
				"#":
					walls.set_cell(cell, 0, Vector2i.ZERO)
				".":
					pass
				"A", "B", "O", "o":
					ends[ch] = _center(Rect2i(cell, Vector2i.ONE))
				_:
					if ch == "T":
						# 隧道先铺成墙，矿工已救时才打开。
						walls.set_cell(cell, 0, Vector2i.ZERO)
					if MARKERS.has(ch):
						_add_marker(root, area, ch, cell)
					else:
						marks[cell] = ch
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
		var node := _place(root, entities, ch, rect, kind, npcs)
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

func _place(root: Node, parent: Node, ch: String, rect: Rect2i, kind: Kind, npcs: Dictionary) -> Node2D:
	if ROLES.has(ch):
		if kind == Kind.LEVEL:
			return _place_npc(root, parent, ch, rect)
		return _place_help(root, parent, ch, rect, kind, npcs)
	if HINTS.has(ch):
		var hint := _instance(HINT_SCENE) as Hint
		hint.hint_id = HINTS[ch]
		hint.position = _center(rect)
		_add(root, parent, hint)
		return hint
	if not SCENES.has(ch):
		push_error("未知图例 %s，位置 %s" % [ch, rect.position])
		return null
	var node := _instance(ESCAPE_SCENE if kind == Kind.OUTRO and ch == "E" else SCENES[ch])
	var size := Vector2(rect.size * TILE)
	match ch:
		">", "<", "^", "v":
			node.rotation = STRIP_ANGLE[ch]
			node.set("size", size if ch == ">" or ch == "<" else Vector2(size.y, size.x))
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
	node.position = _center(rect)
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
