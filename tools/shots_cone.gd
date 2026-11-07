extends Node2D
## 诊断：只放一盏锥形光，看它会不会在暗场里画出一个方框。
##   godot --path . --rendering-driver opengl3 --write-movie /tmp/cone/f.png --fixed-fps 30 res://tools/shots_cone.tscn

func _ready() -> void:
	var shade := CanvasModulate.new()
	shade.color = Color(0.12, 0.12, 0.16)
	add_child(shade)
	# 一面墙，用来对比
	var wall := ColorRect.new()
	wall.color = Color(0.25, 0.2, 0.16)
	wall.position = Vector2(0, 0)
	wall.size = Vector2(1280, 720)
	add_child(wall)
	var light := PointLight2D.new()
	light.texture = Lighting.cone_texture(16.0)
	light.color = Color(1.0, 0.86, 0.55)
	light.energy = 1.3
	light.texture_scale = 1.5
	light.position = Vector2(640, 360)
	Lighting.enable_shadows(light)
	add_child(light)
	for i in 60:
		await get_tree().process_frame
	get_tree().quit()
