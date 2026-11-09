extends Node
## 渲染制作名单，确认排版。

func _ready() -> void:
	var panel := (load("res://scenes/ui/credits.tscn") as PackedScene).instantiate()
	add_child(panel)
	for i in 30:
		await get_tree().process_frame
	get_tree().quit()
