extends Node2D
## 渲染 Helping 特效用的小场景：把 HelpFx 放在屏幕中间，抓几帧看形状。

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.09)
	bg.size = Vector2(1280, 720)
	add_child(bg)
	var fx := HelpFx.new()
	fx.color = Color("ffe9b0")
	fx.scale = Vector2(1.6, 1.6)
	fx.material = Lighting.unshaded()
	fx.global_position = Vector2(640, 360)
	add_child(fx)
	for i in 60:
		await get_tree().process_frame
	get_tree().quit()
