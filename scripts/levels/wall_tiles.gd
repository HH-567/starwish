class_name WallTiles
## 墙和地面图块的共用规则（tools/build_test_levels.gd 建关卡、运行时撞碎墙/开隧道都用它）。
##
## 图块集 data/tiles.tres 里每种风格占三个图源：墙、边界墙（撞不碎）、地面。
##   风格 s：墙 = 3s，边界 = 3s + 1，地面 = 3s + 2。0 = 郊区，1 = 城市。
## 每个图源是 16 列 × 4 行的图集（tools/tile_art.py 生成）：列 = 四邻掩码，行 = 变体。
##   墙的掩码位 = 这一边挨着空地：画墙沿高光，遮光体在这一边往里缩 RIM px，光能照亮墙沿。
##   地面的掩码位 = 这一边挨着墙：画墙脚的接触阴影。

const UP := 1
const RIGHT := 2
const DOWN := 4
const LEFT := 8
const MASKS := 16
const VARIANTS := 4
## 遮光体在挨着空地的那一边往里缩多少（px）：光照进墙沿这么宽。
const RIM := 7.0
const STYLES := ["suburb", "city"]
const DIRS := [[UP, Vector2i.UP], [RIGHT, Vector2i.RIGHT], [DOWN, Vector2i.DOWN], [LEFT, Vector2i.LEFT]]

static func wall_source(style: int, unbreakable: bool) -> int:
	return style * 3 + (1 if unbreakable else 0)

static func floor_source(style: int) -> int:
	return style * 3 + 2

## 按格子坐标挑变体：同一张图每次构建结果一样。
static func variant(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663) % VARIANTS

static func is_wall(walls: TileMapLayer, cell: Vector2i) -> bool:
	return walls.get_cell_source_id(cell) != -1

## 墙格的掩码：哪几边挨着空地。
static func wall_mask(walls: TileMapLayer, cell: Vector2i) -> int:
	var m := 0
	for d: Array in DIRS:
		if not is_wall(walls, cell + d[1]):
			m |= d[0]
	return m

## 地面格的掩码：哪几边挨着墙。
static func floor_mask(walls: TileMapLayer, cell: Vector2i) -> int:
	var m := 0
	for d: Array in DIRS:
		if is_wall(walls, cell + d[1]):
			m |= d[0]
	return m

## 墙格被擦掉（阶段 5 撞碎、矿工的隧道）之后：周围一圈墙重新算墙沿，空出来的格子和周围地面重新铺。
## ground 可以是 null（测试里单独摆的一列墙没有地面层）。
static func refresh_around(walls: TileMapLayer, ground: TileMapLayer, cells: Array[Vector2i]) -> void:
	var touched := {}
	for c in cells:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				touched[c + Vector2i(dx, dy)] = true
	for c: Vector2i in touched:
		var src := walls.get_cell_source_id(c)
		if src != -1:
			walls.set_cell(c, src, Vector2i(wall_mask(walls, c), variant(c)))
		elif ground != null:
			var fsrc := ground.get_cell_source_id(c)
			if fsrc == -1:
				fsrc = _floor_source_near(walls, ground, c)
			if fsrc != -1:
				ground.set_cell(c, fsrc, Vector2i(floor_mask(walls, c), variant(c)))

## 新空出来的格子用哪种地面：看周围已有的地面或墙是哪种风格。
static func _floor_source_near(walls: TileMapLayer, ground: TileMapLayer, c: Vector2i) -> int:
	for d: Array in DIRS:
		var f := ground.get_cell_source_id(c + d[1])
		if f != -1:
			return f
	for d: Array in DIRS:
		var w := walls.get_cell_source_id(c + d[1])
		if w != -1:
			return (w / 3) * 3 + 2
	return -1

## 墙图块的遮光体：四边形，挨着空地的边往里缩 RIM。
static func occluder_for(mask: int, tile: float) -> OccluderPolygon2D:
	var h := tile * 0.5
	var l := -h + (RIM if mask & LEFT else 0.0)
	var r := h - (RIM if mask & RIGHT else 0.0)
	var t := -h + (RIM if mask & UP else 0.0)
	var b := h - (RIM if mask & DOWN else 0.0)
	var occ := OccluderPolygon2D.new()
	occ.polygon = PackedVector2Array([Vector2(l, t), Vector2(r, t), Vector2(r, b), Vector2(l, b)])
	return occ
