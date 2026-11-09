extends Node2D
## 渲染暂停菜单 / 标题，确认图标化的样子。

func _ready() -> void:
	Game.flow = Game.Flow.PAUSED
	var menu := (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	for i in 40:
		await get_tree().process_frame
	get_tree().quit()
