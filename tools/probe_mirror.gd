extends Node
## 探针：ch1 医生房 —— 镜子反射到底通不通。
##   godot --headless --path . res://tools/probe_mirror.tscn

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Save.clear()
	add_child((load("res://scenes/levels/ch1_vine.tscn") as PackedScene).instantiate())
	for i in 5:
		await get_tree().physics_frame
	var p := get_tree().get_first_node_in_group(&"player") as Player
	p.aim_from_mouse = false
	p.global_position = Vector2(52.5, 21.5) * 32.0
	p.light_mode = Player.LightMode.FOCUS
	p.aim = Vector2.UP
	var sl := p.get_node_or_null(^"Light")
	if sl == null:
		print("找不到 Light 节点，子节点：", p.get_children())
		get_tree().quit()
		return
	var doctor: Npc = null
	for n in get_tree().get_current_scene().find_children("*", "Npc", true, false):
		if (n as Npc).role == "doctor":
			doctor = n
	print("医生位置：", doctor.global_position if doctor != null else "没找到")
	for i in 30:
		await get_tree().physics_frame
	print("reflecting=%s dir=%s from=%s range=%.0f" % [sl.get("reflecting"), sl.get("reflect_dir"), sl.get("reflect_from"), sl.get("reflect_range")])
	print("救到：", Save.rescued)
	if doctor != null:
		print("医生到反射起点距离：%.0f" % sl.get("reflect_from").distance_to(doctor.global_position))
		print("角度差：%.1f 度" % rad_to_deg(sl.get("reflect_dir").angle_to(doctor.global_position - sl.get("reflect_from"))))
	get_tree().quit()
