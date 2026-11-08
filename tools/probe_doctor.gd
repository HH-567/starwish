extends Node
## 探针：ch1 医生房间——从下面那道口往上照，能不能照到医生。
##   godot --headless --path . res://tools/probe_doctor.tscn

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Save.clear()
	var chapter: Chapter = (load("res://scenes/levels/ch1_vine.tscn") as PackedScene).instantiate()
	add_child(chapter)
	var player := get_tree().get_first_node_in_group(&"player") as Player
	while player.state != Player.State.ACTIVE:
		await get_tree().physics_frame
	var doctor: Node2D = null
	for node in chapter.find_children("*", "Node2D", true, false):
		if node is Npc and String((node as Npc).role) == "doctor":
			doctor = node as Npc
			break
	if doctor == null:
		print("DOC 找不到医生")
		get_tree().quit()
		return
	print("DOC 组=%s mail=%s 状态=%d" % [
		doctor.is_in_group(&"light_receiver"), (doctor as Npc).mail, int((doctor as Npc).state)])
	print("DOC 医生在 %s（格 %.1f, %.1f）" % [
		doctor.global_position, doctor.global_position.x / 32.0, doctor.global_position.y / 32.0])
	# 站在通风口正下方，散射光照
	for spot: Vector2 in [Vector2(54.5, 20.5), Vector2(53.5, 20.5), Vector2(52.5, 20.5)]:
		Save.clear()
		player.global_position = spot * 32.0
		player.light_mode = Player.LightMode.SCATTER
		player.light = player.light_max
		for i in 120:
			await get_tree().physics_frame
		print("DOC 站 (%.1f, %.1f) 散射：救到=%s 距离=%.0f 亮度=%.1f/%.1f 半径=%.0f 状态=%d" % [
			spot.x, spot.y, Save.has_role(&"doctor"),
			player.global_position.distance_to(doctor.global_position),
			player.light, player.light_max,
			Game.tuning.scatter_radius(player.light), player.state])
		print("DOC 进度 %.2f / 需要 %.2f" % [(doctor as Npc).progress, (doctor as Npc).need()])
	# 聚光再试
	Save.clear()
	player.global_position = Vector2(54.5, 20.5) * 32.0
	player.light_mode = Player.LightMode.FOCUS
	player.aim = Vector2.UP
	player.light = player.light_max
	for i in 120:
		await get_tree().physics_frame
	print("DOC 聚光朝上：救到=%s 医生被照=%s" % [Save.has_role(&"doctor"), (doctor as Npc).is_lit()])
	var space := player.get_world_2d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(
		player.global_position, doctor.global_position, Layers.WALLS))
	print("DOC 视线阻挡：%s" % (hit.get("collider") if not hit.is_empty() else "无"))
	get_tree().quit()
