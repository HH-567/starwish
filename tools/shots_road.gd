extends Node2D
## 截"铺路"演出：开终章，把小星挪到点灯的人那儿触发，录一段镜头左移 + 加速带亮起来。
##   godot --path . --rendering-driver opengl3 --write-movie /tmp/road/f.png --fixed-fps 30 res://tools/shots_road.tscn

func _ready() -> void:
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Game.player_died.disconnect(Game._on_player_died)
	Save.clear()
	Game.flow = Game.Flow.PLAYING
	get_tree().change_scene_to_file(Game.FINALE_SCENE)
	await get_tree().process_frame
	for i in 900:
		await get_tree().physics_frame
		var f := get_tree().current_scene as Finale
		if f != null and f.player != null and f.player.state == Player.State.ACTIVE:
			break
	var finale := get_tree().current_scene as Finale
	var player := finale.player
	var lighter := get_tree().get_first_node_in_group(&"road_lighter") as Node2D
	if lighter == null:
		get_tree().quit()
		return
	# 挪到点灯的人前面一点，让它触发
	player.global_position = lighter.global_position + Vector2(-40.0, 0.0)
	player.velocity = Vector2.LEFT * 700.0
	for i in 80:
		await get_tree().process_frame
	get_tree().quit()
