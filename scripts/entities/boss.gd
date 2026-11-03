class_name Boss
extends Node2D
## 噬光者（docs/state-machines.md 第 12 节）：沿小星走过的路追，无视墙；碰到小星就吸亮度。
## 守夜人的盾挡一次、钟表匠让它减速、乐手把它震退。小星从科学家的虫洞掉头冲回来时，它不再沿轨迹走，
## 直接扑上去：小星这时在阶段 5，它就碎了；不到阶段 5 只会被吸光。
## 身体是一团黑影，周围一圈把光吃掉的暗（减法光源），眼睛和边缘自己发光。

enum State { DORMANT, EMERGE, CHASE, RETREAT, SHATTERED }

const RADIUS := 56.0
## 每隔多久记一个小星的位置。
const TRAIL_STEP := 0.1
const EMERGE_TIME := 1.5
const FADE_TIME := 1.0
## 记多少个走过的点，被震退时沿着它们往回退。
const PASSED_MAX := 400
const BODY := Color("05030a")
const RIM := Color("5a2a7a")
const EYE := Color("ff5a7a")

var state := State.DORMANT

var _player: Player
## 小星走过、它还没走到的点，最早的在前。
var _trail: Array[Vector2] = []
## 它已经走过的点，最近的在后。
var _passed: Array[Vector2] = []
var _trail_t := 0.0
var _state_t := 0.0
var _emerge_time := EMERGE_TIME
var _slow_left := 0.0
var _touching := false
var _t := 0.0
var _aura: Node2D

func _ready() -> void:
	add_to_group(&"boss")
	visible = false
	var dark := Lighting.point_light(260.0, Color.WHITE, 0.85)
	dark.blend_mode = Light2D.BLEND_MODE_SUB
	add_child(dark)
	_aura = Node2D.new()
	_aura.material = Lighting.unshaded()
	_aura.draw.connect(_draw_aura)
	add_child(_aura)

## 在 at 出现，time 秒后开始追 player。终章开头和复活时调用。
func emerge(player: Player, at: Vector2, time := EMERGE_TIME) -> void:
	_player = player
	global_position = at
	_trail.clear()
	_passed.clear()
	_slow_left = 0.0
	_touching = false
	_emerge_time = time
	visible = true
	_set_state(State.EMERGE)

## 小星到了逃离点：退回黑暗。
func retreat() -> void:
	if state == State.EMERGE or state == State.CHASE:
		_set_state(State.RETREAT)

## 钟表匠：time 秒内速度乘 help_slow_mult。
func slow(time: float) -> void:
	_slow_left = maxf(_slow_left, time)

## 乐手、守夜人的盾：沿走过的路往回退 distance。
func knockback(distance: float) -> void:
	if state != State.CHASE:
		return
	while distance > 0.0:
		var back: Vector2
		if _passed.is_empty():
			# 刚出现、没有走过的路：直接往远离小星的方向退。
			back = global_position + (global_position - _player.global_position).normalized() * distance
		else:
			back = _passed[-1]
		var d := global_position.distance_to(back)
		_trail.push_front(global_position)
		if d <= distance and not _passed.is_empty():
			global_position = back
			_passed.pop_back()
			distance -= d
		else:
			global_position = global_position.move_toward(back, distance)
			distance = 0.0

## 沿轨迹算，落后小星多远。
func gap() -> float:
	var total := 0.0
	var from := global_position
	for p in _trail:
		total += from.distance_to(p)
		from = p
	return total + from.distance_to(_player.global_position)

func _physics_process(delta: float) -> void:
	_t += delta
	_state_t += delta
	match state:
		State.EMERGE:
			if _state_t >= _emerge_time:
				_set_state(State.CHASE)
		State.CHASE:
			_slow_left = maxf(_slow_left - delta, 0.0)
			if _player.charged:
				# 小星从科学家的虫洞掉头冲回来：不再沿轨迹走，直接扑上去。
				_trail.clear()
				global_position = global_position.move_toward(_player.global_position, _speed() * delta)
			else:
				_record(delta)
				_advance(_speed() * delta)
			_check_contact(delta)
		State.RETREAT, State.SHATTERED:
			if _state_t >= FADE_TIME:
				visible = false
				set_physics_process(false)
	queue_redraw()
	_aura.queue_redraw()

func _set_state(next: State) -> void:
	state = next
	_state_t = 0.0
	if next == State.SHATTERED:
		Debris.spawn(get_parent(), global_position, Color("fff2c0"), 40, 520.0, 9.0, true)
		Game.player_hit.emit(&"boss")
	Game.boss_state_changed.emit(next)

func _record(delta: float) -> void:
	_trail_t += delta
	if _trail_t >= TRAIL_STEP:
		_trail_t = 0.0
		if _player.state == Player.State.ACTIVE:
			_trail.append(_player.global_position)

func _speed() -> float:
	var t := Game.tuning
	var s := t.boss_speed * (t.help_slow_mult if _slow_left > 0.0 else 1.0)
	if gap() > t.boss_gap_max:
		s = maxf(s, t.boss_catch_speed)
	return s

## 沿轨迹往前走 step；轨迹走完了（小星停住）就直接朝小星走。
func _advance(step: float) -> void:
	while step > 0.0 and not _trail.is_empty():
		var target := _trail[0]
		var d := global_position.distance_to(target)
		if d > step:
			global_position = global_position.move_toward(target, step)
			return
		_passed.append(global_position)
		global_position = target
		_trail.pop_front()
		step -= d
	if _passed.size() > PASSED_MAX:
		_passed = _passed.slice(_passed.size() - PASSED_MAX)
	if step > 0.0:
		global_position = global_position.move_toward(_player.global_position, step)

func _check_contact(delta: float) -> void:
	if _player.state != Player.State.ACTIVE or global_position.distance_to(_player.global_position) > RADIUS + Player.RADIUS:
		_touching = false
		return
	if _player.charged:
		# 掉头的机会只有一次：撞上了，不管碎没碎都用掉。
		_player.charged = false
		if _player.stage == 5:
			_set_state(State.SHATTERED)
			return
	if not _touching and _player.shield:
		# 守夜人的盾挡掉这一次，噬光者被弹回去一点。
		_player.shield = false
		Game.player_hit.emit(&"shield")
		knockback(Game.tuning.help_knockback * 0.5)
		return
	_touching = true
	_player.drain(Game.tuning.boss_drain * delta)

func _scale() -> float:
	match state:
		State.EMERGE:
			return clampf(_state_t / _emerge_time, 0.0, 1.0)
		State.RETREAT:
			return 1.0 - clampf(_state_t / FADE_TIME, 0.0, 1.0)
		State.SHATTERED:
			return 0.0
	return 1.0

func _draw() -> void:
	var s := _scale()
	if s <= 0.0:
		return
	# 一团黑影，边上有几条慢慢摆动的触手。
	draw_circle(Vector2.ZERO, RADIUS * s, BODY)
	for k in 7:
		var a := TAU * k / 7.0 + sin(_t * 1.3 + k) * 0.25
		var pts := PackedVector2Array()
		for i in 6:
			var r := RADIUS * s * (0.8 + i * 0.18)
			pts.append(Vector2.from_angle(a + sin(_t * 2.0 + i * 0.7 + k) * 0.15 * i) * r)
		draw_polyline(pts, BODY, 9.0 * s * (1.0 - 0.1 * k / 7.0))

func _draw_aura() -> void:
	var s := _scale()
	if s <= 0.0:
		return
	_aura.draw_arc(Vector2.ZERO, RADIUS * s, 0.0, TAU, 48, Color(RIM, 0.7), 3.0, true)
	var look := Vector2.LEFT
	if _player != null:
		look = (_player.global_position - global_position).normalized()
	var blink := 1.0 if fmod(_t, 3.7) > 0.12 else 0.2
	for side: float in [-1.0, 1.0]:
		var p := look * RADIUS * 0.35 + look.orthogonal() * side * 14.0
		_aura.draw_circle(p * s, 5.5 * s, Color(EYE, blink))
		_aura.draw_circle(p * s, 11.0 * s, Color(EYE, 0.2 * blink))
