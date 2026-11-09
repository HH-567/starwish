extends Node
## 截图巡游：把小星依次放到一章里每个"有东西"的地方（小人、镜子、影鬼、机关、出口），各停一会儿录帧。
##   godot --path . --rendering-driver opengl3 --write-movie .tmp_build/shots/ch1/f.png --fixed-fps 30 res://tools/shots_tour.tscn -- ch1
## 每个镜头打印 "SHOT <帧号> <标签>"，录完自动退出。参数是 Game.chapters 里的 id（默认 ch0）。

const HOLD := 24
const KINDS := ["Npc", "Mirror", "Enemy", "CrackedWall", "ShadowVine", "IronDoor", "Bars", "Wormhole", "Exit", "Checkpoint", "Meteor", "BlackHole", "Pad"]

var _walls: TileMapLayer

func _ready() -> void:
	Game.debug_no_decay = true
	Game.debug_panel = false
	# 死了会重载当前场景（也就是这个巡游），一路死循环：断开它，并且让影鬼别开枪。
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_enemies = true
	var args := OS.get_cmdline_user_args()
	var id := args[0] if args.size() > 0 else "ch0"
	var path := ""
	for c: Array in Game.chapters:
		if String(c[0]) == id:
			path = c[1]
	if path == "":
		path = "res://scenes/levels/%s.tscn" % id
	add_child((load(path) as PackedScene).instantiate())
	if "glow" in args:
		var env := Environment.new()
		env.background_mode = Environment.BG_CANVAS
		env.glow_enabled = true
		env.glow_intensity = 1.0
		env.glow_bloom = 0.15
		env.glow_hdr_threshold = 0.6
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
		var we := WorldEnvironment.new()
		we.environment = env
		add_child(we)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	player.aim_from_mouse = false
	var cam := player.get_node("Camera") as Camera2D
	_walls = get_tree().current_scene.find_child("Walls", true, false) as TileMapLayer
	while player.state != Player.State.ACTIVE:
		await get_tree().process_frame
	await _hold(HOLD)
	print("SHOT %d spawn" % (Engine.get_frames_drawn() - 1))
	var seen := {}
	for kind: String in KINDS:
		for node in get_tree().current_scene.find_children("*", kind, true, false):
			var n := node as Node2D
			var cell := _walls.local_to_map(_walls.to_local(n.global_position))
			var key := Vector2i(cell.x / 6, cell.y / 6)
			if seen.has(key):
				continue
			seen[key] = true
			var at := _free_near(cell)
			player.global_position = _walls.to_global(_walls.map_to_local(at))
			player.velocity = Vector2.ZERO
			player.hurt_left = 99.0
			var to := n.global_position - player.global_position
			player.aim = to.normalized() if to.length() > 1.0 else Vector2.RIGHT
			cam.reset_smoothing()
			await _hold(HOLD)
			print("SHOT %d %s@%s" % [Engine.get_frames_drawn() - 1, kind, cell])
	get_tree().quit()

func _hold(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

## 离 cell 最近、往外 2 格以上的一个空格（BFS）。
func _free_near(cell: Vector2i) -> Vector2i:
	var q: Array[Vector2i] = [cell]
	var seen := {cell: true}
	var best := cell
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if _walls.get_cell_tile_data(c) == null and _clear(c) and c.distance_to(cell) >= 2.0:
			return c
		if _walls.get_cell_tile_data(c) == null:
			best = c
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nb := c + d
			if not seen.has(nb) and absi(nb.x - cell.x) < 12 and absi(nb.y - cell.y) < 12:
				seen[nb] = true
				q.append(nb)
	return best

func _clear(c: Vector2i) -> bool:
	for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if _walls.get_cell_tile_data(c + d) != null:
			return false
	return true
