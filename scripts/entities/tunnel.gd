@tool
class_name Tunnel
extends Node2D
## 矿工挖的隧道，是矿工帮助点的子节点。地图上这一块先铺成墙；矿工已救时帮助点调 open()，
## 擦掉这块范围里的墙，变成一条捷径。矿工没救时它跟着帮助点一起删掉，墙留着。
## 打开后上下两边有发光的木撑子，看得出是挖出来的路。

const BEAM := Color("c8a070")
const POST_GAP := 64.0

@export var size := Vector2(320.0, 96.0):
	set(value):
		size = value
		queue_redraw()

var opened := false

func open() -> void:
	var walls := _walls()
	if walls == null:
		push_error("隧道 %s 找不到 Walls" % get_path())
		return
	# 往里缩 1 px，只擦范围里面的格子，不碰贴着边的邻格。
	var half := size * 0.5 - Vector2.ONE
	var a := walls.local_to_map(walls.to_local(global_position - half))
	var b := walls.local_to_map(walls.to_local(global_position + half))
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			var data := walls.get_cell_tile_data(Vector2i(x, y))
			if data != null and not data.get_custom_data("unbreakable"):
				walls.erase_cell(Vector2i(x, y))
	walls.update_internals()
	opened = true
	material = Lighting.unshaded()
	queue_redraw()

## 往上找第一个有 Walls 子节点的祖先（赛道），用它的墙。
func _walls() -> TileMapLayer:
	var n := get_parent()
	while n != null and not n.has_node(^"Walls"):
		n = n.get_parent()
	return n.get_node(^"Walls") as TileMapLayer if n != null else null

func _draw() -> void:
	if not opened and not Engine.is_editor_hint():
		return
	var half := size * 0.5
	var c := Color(BEAM, 0.5)
	for s in [-1.0, 1.0]:
		draw_line(Vector2(-half.x, s * half.y), Vector2(half.x, s * half.y), c, 2.0)
	var n := maxi(int(size.x / POST_GAP), 1)
	for i in n + 1:
		var x := -half.x + size.x * i / n
		draw_line(Vector2(x, -half.y), Vector2(x, -half.y + 10.0), c, 3.0)
		draw_line(Vector2(x, half.y), Vector2(x, half.y - 10.0), c, 3.0)
