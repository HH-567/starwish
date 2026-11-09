extends Node2D
## 渲染设置面板，确认"全图形"的样子。

func _ready() -> void:
	Game.flow = Game.Flow.TITLE   # 让难度那一行显示
	var panel := (load("res://scenes/ui/settings.tscn") as PackedScene).instantiate()
	add_child(panel)
	for i in 50:
		await get_tree().process_frame
	get_tree().quit()
