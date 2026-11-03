extends Node
## 截图用：结伴之章的几个镜头，配合 Movie Maker 录帧看画面。
##   godot --path . --rendering-driver opengl3 --write-movie /tmp/ch4/f.png --fixed-fps 30 res://tools/shots_ch4.tscn
## 每个镜头的帧编号会打印出来。录完自动退出。

const LEVEL := "res://scenes/levels/ch4_pair.tscn"
## 小星所在的格子、光圈模式（0 散射、1 聚光）、瞄准方向、停多少帧。
const POSES := [
	[Vector2i(3, 22), 0, Vector2.RIGHT, 30],
	[Vector2i(27, 20), 0, Vector2.UP, 130],       # 两人中间：一起得救
	[Vector2i(34, 20), 0, Vector2.RIGHT, 40],     # 黑洞
	[Vector2i(41, 20), 0, Vector2.RIGHT, 110],    # 流星预警圈
	[Vector2i(50, 18), 0, Vector2.DOWN, 120],     # 钟表匠
	[Vector2i(55, 18), 0, Vector2.RIGHT, 30],     # 铁门
	[Vector2i(61, 22), 0, Vector2.RIGHT, 30],     # 出口
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
		for i in pose[3]:
			await get_tree().process_frame
		print("SHOT %d" % (Engine.get_frames_drawn() - 1))
	get_tree().quit()
