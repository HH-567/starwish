extends Node
## 截图用：序章的几个镜头，配合 Movie Maker 录帧看画面。
##   godot --path . --rendering-driver opengl3 --write-movie /tmp/ch0/f.png --fixed-fps 30 res://tools/shots_ch0.tscn
## 每个镜头的帧编号会打印出来。录完自动退出。

const LEVEL := "res://scenes/levels/ch0_fall.tscn"
## 小星所在的格子、是否聚光、瞄准方向、停多少帧、动作（"rescue" = 先照亮守夜人）。
const POSES := [
	[Vector2i(3, 20), false, Vector2.RIGHT, 30, ""],
	[Vector2i(4, 11), false, Vector2.RIGHT, 20, ""],
	[Vector2i(8, 9), false, Vector2.RIGHT, 30, ""],
	[Vector2i(20, 9), false, Vector2.RIGHT, 30, ""],
	[Vector2i(30, 9), false, Vector2.RIGHT, 30, ""],
	[Vector2i(36, 9), false, Vector2.RIGHT, 30, ""],
	[Vector2i(37, 9), false, Vector2.RIGHT, 130, "rescue"],
	[Vector2i(41, 9), false, Vector2.RIGHT, 40, ""],
]

func _ready() -> void:
	Game.debug_no_decay = true
	Game.debug_panel = false
	add_child((load(LEVEL) as PackedScene).instantiate())
	var player := get_tree().get_first_node_in_group(&"player") as Player
	player.aim_from_mouse = false
	var cam := player.get_node("Camera") as Camera2D
	while player.state != Player.State.ACTIVE:
		await get_tree().process_frame
	for pose: Array in POSES:
		if pose[4] == "rescue":
			var npc := get_tree().get_first_node_in_group(&"npc") as Npc
			player.global_position = Vector2(pose[0]) * 32.0 + Vector2(16, 16)
			player.velocity = Vector2.ZERO
			cam.reset_smoothing()
			await get_tree().process_frame
			npc.receive_light(Player.LightMode.SCATTER, 0.0)
		player.global_position = Vector2(pose[0]) * 32.0 + Vector2(16, 16)
		player.velocity = Vector2.ZERO
		player.light_mode = Player.LightMode.FOCUS if pose[1] else Player.LightMode.SCATTER
		player.aim = (pose[2] as Vector2).normalized()
		cam.reset_smoothing()
		for i in pose[3]:
			await get_tree().process_frame
		print("SHOT %d" % (Engine.get_frames_drawn() - 1))
	get_tree().quit()
