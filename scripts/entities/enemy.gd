@tool
class_name Enemy
extends StaticBody2D
## 影鬼（docs/state-machines.md 第 12 节）：蹲在暗处的射手。
## IDLE →（看见小星）AIM（画一条红线瞄着）→ FIRE（打出一发会反弹的弹幕）→ COOLDOWN → IDLE。
## 三种死法：小星撞上来、弹幕弹回来打中它自己、或者别的影鬼的弹幕打中它。
## 它自己不挡路（没有墙的碰撞层），所以小星可以直接冲过去把它撞散。

enum State { IDLE, AIM, FIRE, COOLDOWN }

const BODY_COLOR := Color("171528")
const EDGE_COLOR := Color("6a4b8f")
const EYE_COLOR := Color("ff5a4a")
const SHOT_SCENE := preload("res://scenes/entities/shot.tscn")

## 这四样按 docs 第 3 节，是实体自己的参数，摆进地图时可以逐个调。
@export var range_px := 420.0
@export var aim_time := 0.6
@export var cooldown := 2.4
@export var radius := 16.0
## 第几章的影鬼（1 起）。构建器按章节表填；一章比一章狠：瞄得快、冷却短，第三章起改成一梭两发。
@export var tier := 1

var state := State.IDLE
var time := 0.0
## 瞄准方向，AIM 期间一直跟着小星转。
var aim_dir := Vector2.RIGHT
## 被打中后先定住闪白一小会再炸开（0.06 秒 = 约 4 帧），比"一帧消失"有打击感。
const HIT_HOLD := 0.06
var _dying := false
var _hit_left := 0.0
var _kill_reason := &""

## 这一只实际用的瞄准时间、冷却、一次打几发。
func _aim_time() -> float:
	return aim_time * maxf(1.0 - Game.tuning.enemy_aim_step * (tier - 1), 0.35)

func _cooldown() -> float:
	return cooldown * maxf(1.0 - Game.tuning.enemy_cool_step * (tier - 1), 0.35)

func _volley() -> int:
	return 2 if tier >= Game.tuning.enemy_double_from else 1

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	material = Lighting.unshaded()
	collision_layer = Layers.ENEMY
	collision_mask = 0
	Shapes.add_rect(self, Vector2(radius * 2.0, radius * 2.0))
	_load_art()
	_set_state(State.IDLE)

## 有美术图就挂一个 Sprite，状态切换时换图。
func _load_art() -> void:
	if ResourceLoader.exists(ART_IDLE):
		_tex_idle = load(ART_IDLE) as Texture2D
	if ResourceLoader.exists(ART_AIM):
		_tex_aim = load(ART_AIM) as Texture2D
	if ResourceLoader.exists(ART_FIRE):
		_tex_fire = load(ART_FIRE) as Texture2D
	if _tex_idle == null and _tex_aim == null:
		return
	_art = Sprite2D.new()
	_art.texture = _tex_idle if _tex_idle != null else _tex_aim
	# 身体画在自己的 _draw 下面：眼睛和瞄准红线要压在身体上面。
	_art.show_behind_parent = true
	add_child(_art)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _dying:
		_hit_left -= delta
		if _hit_left <= 0.0:
			_burst()
		return
	if get_tree().paused:
		return
	if Game.debug_no_enemies:
		return
	time += delta
	var player := get_tree().get_first_node_in_group(&"player") as Player
	# 小星贴到身上：不管在干什么都被撞散
	if state != State.FIRE and _touching(player):
		_kill(&"charge")
		return
	match state:
		State.IDLE:
			if _can_see(player):
				aim_dir = (player.global_position - global_position).normalized()
				_set_state(State.AIM)
				# 瞄准声按这一只的瞄准时间变调：嗡声走到最高的那一刻正好开枪。
				_aim_sound = Audio.play_at(&"aim", global_position, AIM_SOUND_TIME / _aim_time())
		State.AIM:
			if not _can_see(player):
				# 躲进墙后面就放弃这一枪
				_stop_aim_sound()
				_set_state(State.IDLE)
			else:
				aim_dir = (player.global_position - global_position).normalized()
				if time >= _aim_time():
					_fire()
		State.FIRE:
			_set_state(State.COOLDOWN)
		State.COOLDOWN:
			if time >= _cooldown():
				_set_state(State.IDLE)
	queue_redraw()

## 看得见：小星活着、在射程里、中间没有墙。
func _can_see(player: Player) -> bool:
	if player == null or player.state != Player.State.ACTIVE:
		return false
	if global_position.distance_to(player.global_position) > range_px:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, Layers.WALLS)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _touching(player: Player) -> bool:
	if player == null or player.state != Player.State.ACTIVE:
		return false
	return global_position.distance_to(player.global_position) < radius + Player.RADIUS + 2.0

func _fire() -> void:
	_set_state(State.FIRE)
	if not is_inside_tree():
		return
	var count := _volley()
	var spread := Game.tuning.enemy_spread
	for i in count:
		# 一发打正，两发就左右各偏一点（扇形）
		var offset := 0.0
		if count > 1:
			offset = deg_to_rad(spread) * (float(i) - (count - 1) * 0.5)
		var dir := aim_dir.rotated(offset)
		var shot := SHOT_SCENE.instantiate() as Shot
		shot.direction = dir
		shot.global_position = global_position + dir * (radius + 14.0)
		get_parent().add_child(shot)
	_stop_aim_sound()
	Audio.play_at(&"shot", global_position)

## 瞄准声（aim.wav）原本的长度：它从低到高走 0.6 秒。
const AIM_SOUND_TIME := 0.6
var _aim_sound: AudioStreamPlayer2D

## 放弃瞄准或开枪时把瞄准声掐掉。声部是轮流用的，确认它还在放瞄准声再停。
func _stop_aim_sound() -> void:
	if _aim_sound != null and _aim_sound.stream == Audio.STREAMS[&"aim"]:
		_aim_sound.stop()
	_aim_sound = null

## 死：一团碎片，然后从场上消失。谁打死的记在 Game 的信号里。
func _kill(reason: StringName) -> void:
	if not is_inside_tree() or _dying:
		return
	_stop_aim_sound()
	_dying = true
	_hit_left = HIT_HOLD
	_kill_reason = reason
	# 定格期间闪白：贴图直接提亮，没贴图就整个节点提亮
	if _art != null:
		_art.self_modulate = Color(3.0, 3.0, 3.0)
	else:
		modulate = Color(2.5, 2.5, 2.5)
	queue_redraw()

## 定格结束：炸开、报信号、按连击数放大特效和音高。
func _burst() -> void:
	if not is_inside_tree():
		return
	var combo := Game.hit_combo()
	var grow := 1.0 + 0.12 * float(mini(combo - 1, 5))
	HitBurst.spawn(get_parent(), global_position, EDGE_COLOR, grow)
	Debris.spawn(get_parent(), global_position, EDGE_COLOR, 14 + combo * 2, 240.0, 6.0, true)
	Game.player_hit.emit(&"kill")
	Game.enemy_killed.emit(_kill_reason)
	# 撞碎影鬼有自己的一套声音（和撞墙的 smash、裂墙的 break 分开）；连击越高音越高
	Audio.play_at(&"shatter", global_position, 1.0 + 0.06 * float(mini(combo - 1, 6)))
	queue_free()

## 美术图：待机 / 瞄准 / 开火三张 32×32 剪影。
const ART_IDLE := "res://assets/art/enemies/shade_idle.png"
const ART_AIM := "res://assets/art/enemies/shade_aim.png"
const ART_FIRE := "res://assets/art/enemies/shade_fire.png"

var _art: Sprite2D
var _tex_idle: Texture2D
var _tex_aim: Texture2D
var _tex_fire: Texture2D

func _set_state(next: State) -> void:
	state = next
	time = 0.0
	_sync_art()
	queue_redraw()

func _sync_art() -> void:
	if _art == null:
		return
	var tex := _tex_idle
	if state == State.FIRE and _tex_fire != null:
		tex = _tex_fire
	elif (state == State.AIM or state == State.FIRE) and _tex_aim != null:
		tex = _tex_aim
	if tex != null and _art.texture != tex:
		_art.texture = tex

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, radius, Color(BODY_COLOR, 0.9))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, EDGE_COLOR, 2.0, true)
		return
	if _art != null:
		# 有图时身体交给贴图（跟着环境光，暗处几乎看不见），这里画自己发光的那两点眼睛和瞄准红线：
		# 暗处只看得见一对红眼——瞄准时越睁越大、越来越亮，冷却时眯起来。
		var open := 0.35
		match state:
			State.AIM:
				open = lerpf(0.6, 1.0, clampf(time / maxf(_aim_time(), 0.01), 0.0, 1.0))
			State.FIRE:
				open = 1.0
			State.COOLDOWN:
				open = 0.2
		for s in [-1.0, 1.0]:
			var at := Vector2(2.6 * s, -5.0)
			draw_circle(at, 1.2 + 2.4 * open, Color(EYE_COLOR, 0.18 * open))
			draw_rect(Rect2(at - Vector2(1.0, 0.5 + 0.9 * open), Vector2(2.0, 1.0 + 1.8 * open)), Color(EYE_COLOR, 0.5 + 0.5 * open))
		if state == State.AIM:
			# 按这一只实际的瞄准时间画满：后面几章瞄得快，用 aim_time 算的话红线还没画满就开枪了。
			var k2 := clampf(time / maxf(_aim_time(), 0.01), 0.0, 1.0)
			draw_line(aim_dir * (radius + 2.0), aim_dir * (radius + 40.0 + 260.0 * k2),
					Color(EYE_COLOR, 0.15 + 0.5 * k2), 1.0 + 2.0 * k2)
		return
	var eye := 3.0
	match state:
		State.AIM:
			var k := clampf(time / maxf(_aim_time(), 0.01), 0.0, 1.0)
			eye = lerpf(3.0, 6.0, k)
			# 红线：从身子边缘指向小星，越长越亮，最后一刻最亮
			var from := aim_dir * (radius + 2.0)
			var to := aim_dir * (radius + 40.0 + 260.0 * k)
			draw_line(from, to, Color(EYE_COLOR, 0.15 + 0.5 * k), 1.0 + 2.0 * k)
		State.COOLDOWN:
			eye = 2.0
	draw_circle(Vector2.ZERO, radius, BODY_COLOR)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, EDGE_COLOR, 2.0, true)
	draw_circle(Vector2.ZERO, eye, EYE_COLOR)
