extends Node
## 截图用：裂纹之章的几个镜头，配合 Movie Maker 录帧看画面。
##   godot --path . --rendering-driver opengl3 --write-movie /tmp/ch3/f.png --fixed-fps 30 res://tools/shots_ch3.tscn
## 每个镜头的帧编号会打印出来。录完自动退出。

const LEVEL := "res://scenes/levels/ch3_crack.tscn"
## 小星所在的格子、光圈模式（0 散射、1 聚光）、瞄准方向、停多少帧、动作（"run_right" 按住右跑一段）。
const POSES := [
	[Vector2i(3, 24), 0, Vector2.RIGHT, 30, ""],
	[Vector2i(5, 22), 0, Vector2.UP, 30, ""],        # 铁门
	[Vector2i(29, 20), 0, Vector2.RIGHT, 30, ""],    # 加速带和前面的裂纹墙
	[Vector2i(29, 20), 0, Vector2.RIGHT, 150, "run_right"],
	[Vector2i(51, 19), 0, Vector2.RIGHT, 40, ""],    # 栅栏后的锁匠
	[Vector2i(45, 21), 0, Vector2.RIGHT, 30, ""],    # 检查点
	[Vector2i(62, 20), 0, Vector2.RIGHT, 30, ""],    # 软垫和出口
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
		player.global_position = Vector2(pose[0]) * 32.0 + Vector2(16, 16)
		player.velocity = Vector2.ZERO
		player.light_mode = Player.LightMode.FOCUS if pose[1] == 1 else Player.LightMode.SCATTER
		player.aim = (pose[2] as Vector2).normalized()
		cam.reset_smoothing()
		if pose[4] == "run_right":
			Input.action_press("move_right")
		for i in pose[3]:
			await get_tree().process_frame
		if pose[4] == "run_right":
			Input.action_release("move_right")
		print("SHOT %d" % (Engine.get_frames_drawn() - 1))
	get_tree().quit()
