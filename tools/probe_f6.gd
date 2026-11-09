extends Node
## 探针：验证"一键救援"写进去的 save_id 数和 everyone_rescued。
##   godot --headless --path . res://tools/probe_f6.tscn

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	Game.debug_rescue_all()
	print("F6 救援数=%d everyone=%s" % [Save.rescued.size(), Game.everyone_rescued()])
	print("F6 ids=%s" % [Save.rescued.keys()])
	get_tree().quit()
