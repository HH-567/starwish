extends Node2D
## 截死亡演出：把小星放中间打死，录一段。
##   godot --path . --rendering-driver opengl3 --write-movie /tmp/death/f.png --fixed-fps 30 res://tools/shots_death.tscn

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")

func _ready() -> void:
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Game.player_died.disconnect(Game._on_player_died)
	var player := PLAYER_SCENE.instantiate() as Player
	player.aim_from_mouse = false
	add_child(player)
	while player.state != Player.State.ACTIVE:
		await get_tree().physics_frame
	player.global_position = Vector2(640, 360)
	for i in 40:
		await get_tree().process_frame
	player.blast(player.light_max * 2.0)
	for i in 90:
		await get_tree().process_frame
	get_tree().quit()
