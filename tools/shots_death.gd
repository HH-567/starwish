extends Node2D
## 截死亡演出：先录一段"碎裂"，再录一段"熄灭（化开）"。
##   godot --path . --rendering-driver opengl3 --write-movie /tmp/death/f.png --fixed-fps 30 res://tools/shots_death.tscn

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")

var _player: Player

func _ready() -> void:
	Game.debug_no_decay = true
	Game.debug_no_enemies = true
	Game.player_died.disconnect(Game._on_player_died)
	await _spawn()
	# 第一段：撞碎（blast 打空亮度）
	_player.blast(_player.light_max * 2.0)
	await _frames(70)
	_clear()
	# 第二段：油尽灯枯（直接按熄灭死）
	await _spawn()
	_player._die(Player.Death.EXTINGUISHED)
	await _frames(70)
	get_tree().quit()

func _spawn() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.aim_from_mouse = false
	add_child(_player)
	while _player.state != Player.State.ACTIVE:
		await get_tree().physics_frame
	_player.global_position = Vector2(640, 360)

func _clear() -> void:
	for child in get_children():
		if child is Shatter or child is Dissolve:
			child.queue_free()
	if _player != null:
		_player.queue_free()
		_player = null

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
