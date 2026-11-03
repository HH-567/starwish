extends Node
## 截图用：触屏控件长什么样（两根摇杆 + 光按钮 + 暂停）。
##   godot --path . --rendering-driver opengl3 --write-movie /tmp/touch/f.png --fixed-fps 30 res://tools/shots_touch.tscn

const LEVEL := "res://scenes/levels/ch0_fall.tscn"

func _ready() -> void:
	Game.debug_no_decay = true
	Game.debug_panel = false
	add_child((load(LEVEL) as PackedScene).instantiate())
	var player := get_tree().get_first_node_in_group(&"player") as Player
	while player.state != Player.State.ACTIVE:
		await get_tree().process_frame
	Controls.touch = true
	for i in 10:
		await get_tree().process_frame
	# 两根手指都推出去，好看出摇杆在动。
	_touch(Vector2(220, 560), 0, true)
	_touch(Vector2(1000, 420), 1, true)
	_drag(Vector2(300, 480), 0)
	_drag(Vector2(940, 480), 1)
	for i in 20:
		await get_tree().process_frame
	print("SHOT %d" % (Engine.get_frames_drawn() - 1))
	get_tree().quit()

func _touch(at: Vector2, index: int, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = at
	ev.pressed = pressed
	get_viewport().push_input(ev, true)

func _drag(at: Vector2, index: int) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = at
	get_viewport().push_input(ev, true)
