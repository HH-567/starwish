extends Node
## 截图用：加载光照测试关，把小星依次摆到几个位置，配合 Movie Maker 录帧看画面。
##   godot --path . --rendering-driver opengl3 --write-movie /tmp/shots/f.png --fixed-fps 30 res://tools/shots.tscn
## 每个镜头的最后一帧编号会打印出来。录完自动退出。

const LEVEL := "res://scenes/levels/test_light.tscn"
## 小星位置、是否聚光、瞄准方向、停多少帧、亮度（0 = 不改）、动作（"rescue_all" = 先把所有人救出来）。
const POSES := [
	[Vector2(176, 300), false, Vector2.RIGHT, 20, 0.0, ""],
	[Vector2(500, 190), false, Vector2.RIGHT, 75, 0.0, ""],
	[Vector2(1232, 380), false, Vector2.RIGHT, 20, 0.0, ""],
	[Vector2(1808, 880), false, Vector2.RIGHT, 20, 0.0, ""],
	[Vector2(1776, 848), false, Vector2.RIGHT, 75, 0.0, ""],
	[Vector2(1808, 880), false, Vector2.RIGHT, 30, 0.0, "rescue_all"],
	[Vector2(1712, 200), false, Vector2.RIGHT, 30, 0.0, ""],
	[Vector2(880, 520), false, Vector2.RIGHT, 30, 0.0, ""],
	[Vector2(400, 300), false, Vector2.RIGHT, 30, 0.0, ""],
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
	for pose in POSES:
		if pose[5] == "rescue_all":
			for npc in get_tree().get_nodes_in_group(&"npc"):
				npc.rescue()
		player.global_position = pose[0]
		player.velocity = Vector2.ZERO
		player.light_mode = Player.LightMode.FOCUS if pose[1] else Player.LightMode.SCATTER
		player.aim = (pose[2] as Vector2).normalized()
		if pose[4] > 0.0:
			player.light = pose[4]
		cam.reset_smoothing()
		for i in pose[3]:
			await get_tree().process_frame
		print("SHOT %d" % (Engine.get_frames_drawn() - 1))
	get_tree().quit()
