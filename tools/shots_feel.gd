extends Node
## 截图用：把小星用不同速度朝墙发射，录下撞墙的那几帧，看打击感（压扁、火花、顿挫、定帧）。
##   godot --path . --rendering-driver opengl3 --write-movie .tmp_build/shots/feel/f.png --fixed-fps 30 res://tools/shots_feel.tscn
## 每一发打印 "SHOT <帧号> <速度>"（撞上那一帧），录完自动退出。

const LEVEL := "res://scenes/levels/ch0_fall.tscn"
## 出生房的东墙：从 (3, 23) 往右 6 格就是墙（x=9）。[起点格, 方向, 速度]
const SHOTS := [
	[Vector2i(3, 23), Vector2.RIGHT, 150.0],
	[Vector2i(3, 23), Vector2.RIGHT, 300.0],
	[Vector2i(3, 23), Vector2.RIGHT, 560.0],
	[Vector2i(3, 23), Vector2.RIGHT, 700.0],
]

func _ready() -> void:
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Game.debug_panel = false
	Game.player_died.disconnect(Game._on_player_died)
	add_child((load(LEVEL) as PackedScene).instantiate())
	var player := get_tree().get_first_node_in_group(&"player") as Player
	player.aim_from_mouse = false
	var cam := player.get_node("Camera") as Camera2D
	while player.state != Player.State.ACTIVE:
		await get_tree().process_frame
	var hit := [false]
	Game.player_hit.connect(func(_k: StringName) -> void: hit[0] = true)
	for s: Array in SHOTS:
		player.global_position = Vector2(s[0]) * 32.0 + Vector2(16, 16)
		player.light = 60.0
		player.hurt_left = 0.0
		cam.reset_smoothing()
		await get_tree().physics_frame
		player.velocity = (s[1] as Vector2) * float(s[2])
		hit[0] = false
		for i in 60:
			await get_tree().process_frame
			if hit[0]:
				var sp := player.get_global_transform_with_canvas().origin
				print("SHOT %d %.0f %d %d" % [Engine.get_frames_drawn() - 1, s[2], sp.x, sp.y])
				break
		for i in 20:
			await get_tree().process_frame
	get_tree().quit()
