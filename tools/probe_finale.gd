extends Node
## 探针：F6 进终章后，最后的科学家 / 虫洞 / 逃离点 / 加速带都在哪，能不能把速度推到阶段 5。
##   godot --headless --path . res://tools/probe_finale.tscn

func _ready() -> void:
	get_tree().root.add_child.call_deferred(Runner.new())

class Runner extends Node:
	func _ready() -> void:
		Game.debug_rescue_all()
		Game.flow = Game.Flow.CHASE
		Save.checkpoint = ""
		get_tree().change_scene_to_file(Game.FINALE_SCENE)
		await get_tree().process_frame
		await get_tree().process_frame
		var finale := get_tree().current_scene
		print("FINALE scene=", finale)
		var player := get_tree().get_first_node_in_group(&"player") as Player
		var boss := get_tree().get_first_node_in_group(&"boss") as Boss
		print("FINALE player=", player.global_position, " boss=", boss.global_position, " state=", boss.state)
		for hp in finale.find_children("*", "HelpPoint", true, false):
			var h := hp as HelpPoint
			print("HELP role=%s everyone=%s present=%s at=%s" % [h.role, h.everyone, h.is_present(), h.global_position])
			var wh := h.get_node_or_null(^"Wormhole") as Wormhole
			if wh != null:
				print("  WORM charge=%s two_way=%s keep_dir=%s A=%s B=%s" % [
					wh.charge, wh.two_way, wh.keep_direction,
					(wh.get_node(^"A") as Node2D).global_position, (wh.get_node(^"B") as Node2D).global_position])
		for ep in finale.find_children("*", "EscapePoint", true, false):
			print("ESCAPE at=", (ep as Node2D).global_position)
		var strips := 0
		var strips_left := 0
		for s in finale.find_children("*", "AccelStrip", true, false):
			var st := s as AccelStrip
			strips += 1
			if st.direction.x < -0.5:
				strips_left += 1
		print("STRIPS total=%d leftward=%d" % [strips, strips_left])
		var entries: Array = finale.get("entries")
		print("ENTRIES %s" % [entries.map(func(e: Node2D): return e.global_position)])
		get_tree().quit()
