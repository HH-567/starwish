extends Node2D
## 渲染标题的两种状态：没打真结局（暗、有噬光者）/ 打过真结局（城市亮起、噬光者消失）。
## 用法：godot --path . res://tools/shots_title_states.tscn

func _ready() -> void:
	# 第一种：暗
	Save.endings.clear()
	var dark := (load("res://scenes/ui/title.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(dark)
	for i in 30:
		await get_tree().process_frame
	print("TITLE dark dawn=", dark.get("_dawn"), " lit=", dark.get("_lit"))
	dark.queue_free()
	await get_tree().process_frame
	# 第二种：亮
	Save.endings["hidden"] = true
	var lit := (load("res://scenes/ui/title.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(lit)
	for i in 90:
		await get_tree().process_frame
	print("TITLE lit dawn=", lit.get("_dawn"), " lit=", lit.get("_lit"))
	get_tree().quit()
