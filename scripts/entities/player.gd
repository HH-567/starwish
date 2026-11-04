class_name Player
extends CharacterBody2D
## 小星：移动、速度阶段、撞墙规则、亮度和光的模式。规则见 docs/state-machines.md 第 2 节。
## 照亮目标由子节点 StarLight 负责。数值全部现读 Game.tuning。

enum State { SPAWN, ACTIVE, WARP, LOCKED, DYING }
enum Death { EXTINGUISHED, SHATTERED, DRAINED }
enum LightMode { SCATTER, FOCUS }

const RADIUS := 10.0
const SPAWN_TIME := 0.5
const DYING_TIME := 1.0
const WARP_TIME := 0.15
const MAX_HITS_PER_FRAME := 4
## 法向速度低于它的阶段 1 碰撞不发 bump 信号，免得贴墙时每帧都触发。
const BUMP_MIN := 40.0
## 鼠标离小星这么近时不改瞄准方向。
const AIM_DEADZONE := 4.0
## 触屏右摇杆推到这个比例以上才算在瞄准。
const TOUCH_AIM_DEADZONE := 0.25
const TRAIL_POINTS := 22
const GLOW_TEX := 256
## 星体周围那圈光晕的半径。亮度看光环（StarLight 画的圆）。
const CORONA := 40.0
const STAR_COLOR := Color("ffd75a")
const WARN_COLOR := Color("ff5050")
const SHIELD_COLOR := Color("9fd8ff")
const WALL_DEBRIS := Color("3a4a80")

var state := State.SPAWN
var stage := 1
var light := 0.0
var light_max := 0.0
var light_mode := LightMode.SCATTER
## 瞄准方向，单位向量。键鼠时跟着鼠标；测试里把 aim_from_mouse 关掉直接设。
var aim := Vector2.RIGHT
var aim_from_mouse := true
var death_cause := Death.EXTINGUISHED
## 受伤无敌剩余秒数。
var hurt_left := 0.0
## 反弹保护剩余秒数。
var grace_left := 0.0
## 守夜人给的盾：挡掉下一次噬光者的接触。
var shield := false
## 这一帧的外部加速度（黑洞之类每帧往里加），step_velocity 最后叠上再清掉。
var push := Vector2.ZERO
## 刚从科学家的虫洞出来：一路冲回去，这时以阶段 5 撞上噬光者能把它撞碎。
var charged := false
var charge_left := 0.0

var _state_time := 0.0
var _spin := 0.0
var _trail_points: Array[Vector2] = []
var _warp_to := Vector2.ZERO
var _warp_velocity := Vector2.ZERO

@onready var _trail: Line2D = $Trail
@onready var _glow: Sprite2D = $Glow

func _ready() -> void:
	collision_layer = Layers.PLAYER
	collision_mask = Layers.SOLID
	light_max = Game.light_max()
	light = light_max
	Game.npc_rescued.connect(_on_npc_rescued)
	_setup_visuals()

func _physics_process(delta: float) -> void:
	_state_time += delta
	match state:
		State.SPAWN:
			if _state_time >= SPAWN_TIME:
				_set_state(State.ACTIVE)
		State.ACTIVE:
			hurt_left = maxf(hurt_left - delta, 0.0)
			grace_left = maxf(grace_left - delta, 0.0)
			_read_light_input()
			if charged:
				# 从科学家的虫洞出来：不听方向键，速度不变，一路冲回去。
				charge_left -= delta
				charged = charge_left > 0.0
			else:
				# 触屏时方向来自左摇杆，键鼠时读按键（docs/state-machines.md 第 14 节）。
				var input: Vector2 = Controls.move if Controls.touch else Input.get_vector("move_left", "move_right", "move_up", "move_down")
				velocity = step_velocity(velocity, input, delta)
			_move(delta)
			_update_stage()
			if state == State.ACTIVE:
				_drain_light(delta)
		State.WARP:
			if _state_time >= WARP_TIME:
				_arrive()
		State.DYING:
			if _state_time >= DYING_TIME:
				set_physics_process(false)
				Game.player_died.emit(death_cause)
	_spin += delta * (1.0 + velocity.length() / 160.0)
	_update_visuals()

## 小星星调用：回亮度，不超过上限。医生的帮助是回满。
func add_light(amount: float) -> void:
	light = minf(light + amount, light_max)
	Game.light_changed.emit(light, light_max)

## 噬光者调用：吸走亮度，吸干就死。
func drain(amount: float) -> void:
	if state != State.ACTIVE:
		return
	light = maxf(light - amount, 0.0)
	Game.light_changed.emit(light, light_max)
	if light <= 0.0:
		_die(Death.DRAINED)

## 流星砸中（docs/state-machines.md 第 10 节）：和阶段 2 撞墙一样的代价，但没有反弹。
func blast(amount: float) -> void:
	if state != State.ACTIVE or hurt_left > 0.0:
		return
	if light <= amount:
		light = 0.0
		_die(Death.SHATTERED)
		return
	light -= amount
	hurt_left = Game.tuning.hurt_iframes
	Game.light_changed.emit(light, light_max)
	_hit(&"hurt")

## 科学家的虫洞调用：charge_time 秒内一路冲回去。噬光者碰到它时不管碎没碎都会用掉。
func charge() -> void:
	charged = true
	charge_left = Game.tuning.charge_time

## 噬光者登场、结局演出时锁住：不接受输入，原地不动。出生途中也能锁。
func lock(on: bool) -> void:
	if on and (state == State.ACTIVE or state == State.SPAWN):
		velocity = Vector2.ZERO
		_set_state(State.LOCKED)
	elif not on and state == State.LOCKED:
		_set_state(State.ACTIVE)

## 虫洞调用：消失 WARP_TIME 秒，然后在 to 出现，速度换成 new_velocity。
func warp(to: Vector2, new_velocity: Vector2) -> void:
	if state != State.ACTIVE:
		return
	_warp_to = to
	_warp_velocity = new_velocity
	velocity = Vector2.ZERO
	_set_state(State.WARP)

func _arrive() -> void:
	global_position = _warp_to
	velocity = _warp_velocity
	_trail_points.clear()
	_set_state(State.ACTIVE)
	Game.warped.emit()

## 左键/空格切散射，右键/Shift 切聚光；触屏点"光"按钮来回切。键鼠时瞄准跟着鼠标。
func _read_light_input() -> void:
	if Controls.take_mode_toggle():
		light_mode = LightMode.FOCUS if light_mode == LightMode.SCATTER else LightMode.SCATTER
	elif Input.is_action_just_pressed("light_scatter"):
		light_mode = LightMode.SCATTER
	elif Input.is_action_just_pressed("light_focus"):
		light_mode = LightMode.FOCUS
	if Controls.touch:
		# 触屏：右摇杆瞄准；没推就朝移动方向。
		if Controls.aim.length() > TOUCH_AIM_DEADZONE:
			aim = Controls.aim.normalized()
		elif velocity.length() > 1.0:
			aim = velocity.normalized()
	elif aim_from_mouse:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > AIM_DEADZONE:
			aim = to_mouse.normalized()

## 救人：上限提高并回满。
func _on_npc_rescued(_id: String) -> void:
	light_max = Game.light_max()
	light = light_max
	Game.light_changed.emit(light, light_max)

## 一帧的速度变化：加速、刹车、松手减速、WASD 上限、超速回落、封顶。
## 最后再叠上外部的推力（黑板的吸引之类）：不叠的话松手减速会把它抹掉。
func step_velocity(v: Vector2, input: Vector2, delta: float) -> Vector2:
	var t := Game.tuning
	var old_speed := v.length()
	if input == Vector2.ZERO:
		v = v.move_toward(Vector2.ZERO, t.coast_decel * delta)
	else:
		var acc := input * t.accel
		if old_speed > 0.0:
			# 把输入拆成顺着速度和垂直于速度两部分，分别乘刹车和转弯倍率。
			var dir := v / old_speed
			var along := acc.dot(dir)
			var side := acc - dir * along
			if along < 0.0:
				along *= t.brake_mult
			acc = dir * along + side * t.turn_mult
		v += acc * delta
	var allowed := maxf(Game.input_limit(), old_speed - t.overspeed_decay * delta)
	v = v.limit_length(minf(allowed, t.max_speed))
	if push != Vector2.ZERO:
		# 外部推力（黑洞）不受 WASD 上限约束，但**只在终章**才允许甩过阶段 4 的顶：
		# 关卡里能冲到阶段 5 的话，玩家会一路撞碎黑墙把关卡挖穿。
		var cap := t.max_speed if Game.flow == Game.Flow.CHASE else Game.input_limit()
		v = (v + push * delta).limit_length(cap)
		push = Vector2.ZERO
	return v

## 带回差的阶段判定（docs/state-machines.md 2.2）。回差偏向安全：阶段 2 晚进早出。
func stage_for(speed: float, current: int) -> int:
	var t := Game.tuning
	var s := current
	while s < 5 and speed >= t.stage_min[s] + (t.hysteresis if s == 1 else 0.0):
		s += 1
	while s > 1 and speed < t.stage_min[s - 1] - (0.0 if s == 2 else t.hysteresis):
		s -= 1
	return s

## 加速带调用：沿 dir 的速度提到至少 target，可以超过 WASD 上限，但不超过 max_speed。
func boost(dir: Vector2, target: float) -> void:
	if state != State.ACTIVE:
		return
	var along := velocity.dot(dir)
	if along < 0.0:
		return
	if along < target:
		velocity += dir * (target - along)
	velocity = velocity.limit_length(Game.tuning.max_speed)

func _move(delta: float) -> void:
	var motion := velocity * delta
	for i in MAX_HITS_PER_FRAME:
		var col := move_and_collide(motion)
		if col == null:
			return
		motion = _resolve_hit(col)
		if state != State.ACTIVE or motion.is_zero_approx():
			return

## 按 docs/state-machines.md 2.3 的表处理一次碰撞，返回这一帧剩下的位移。
func _resolve_hit(col: KinematicCollision2D) -> Vector2:
	var t := Game.tuning
	var n := col.get_normal()
	var rest := col.get_remainder()
	var speed := velocity.length()
	var vn := -velocity.dot(n)
	if vn < speed * t.graze_ratio:
		velocity = velocity.slide(n)
		return rest.slide(n)
	var layer := PhysicsServer2D.body_get_collision_layer(col.get_collider_rid())
	var s := stage_for(speed, stage)
	if s == 5 and not _is_unbreakable(col):
		var loss := t.break_speed_loss if layer & Layers.CRACKED else t.smash_speed_loss
		_smash(col)
		velocity *= 1.0 - loss
		_hit(&"smash")
		return rest * (1.0 - loss)
	if layer & Layers.PAD:
		velocity = Vector2.ZERO
		_hit(&"stop")
		return Vector2.ZERO
	if s == 4 and layer & Layers.CRACKED:
		_smash(col)
		velocity *= 1.0 - t.break_speed_loss
		_hit(&"break")
		return rest * (1.0 - t.break_speed_loss)
	if s >= 3 or (s == 2 and grace_left > 0.0):
		velocity = velocity.bounce(n) * t.bounce_restitution
		grace_left = t.bounce_grace
		_hit(&"bounce")
		return rest.bounce(n) * t.bounce_restitution
	if s == 2 and hurt_left <= 0.0:
		_hurt(n)
		return Vector2.ZERO
	# 阶段 1，以及无敌期内的阶段 2：贴墙滑行并减速。
	velocity = velocity.slide(n) * (1.0 - t.s1_wall_loss)
	if vn > BUMP_MIN:
		_hit(&"bump")
	return rest.slide(n) * (1.0 - t.s1_wall_loss)

## 撞到的那一格：从碰撞点沿法线往墙里进 1 像素。
## 不用 get_coords_for_body_rid()：4.5 起图块碰撞按 physics_quadrant_size 合并，它返回的是分块坐标。
func _hit_cell(tiles: TileMapLayer, col: KinematicCollision2D) -> Vector2i:
	return tiles.local_to_map(tiles.to_local(col.get_position() - col.get_normal()))

## 边界图块和铁门：阶段 5 也撞不碎。
func _is_unbreakable(col: KinematicCollision2D) -> bool:
	var body := col.get_collider()
	var tiles := body as TileMapLayer
	if tiles == null:
		return body.get("unbreakable") == true
	var data := tiles.get_cell_tile_data(_hit_cell(tiles, col))
	return data != null and data.get_custom_data("unbreakable")

func _smash(col: KinematicCollision2D) -> void:
	var body := col.get_collider()
	var tiles := body as TileMapLayer
	if tiles == null:
		if body.has_method("smash"):
			body.smash()
		return
	var center := _hit_cell(tiles, col)
	var r := Game.tuning.smash_radius
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			var cell := center + Vector2i(x, y)
			var data := tiles.get_cell_tile_data(cell)
			if data != null and not data.get_custom_data("unbreakable"):
				tiles.erase_cell(cell)
	# 立刻重建碰撞，这一帧剩下的位移才能穿过去。
	tiles.update_internals()
	Debris.spawn(get_parent(), tiles.to_global(tiles.map_to_local(center)), WALL_DEBRIS, 16, 320.0, 8.0)

func _hurt(n: Vector2) -> void:
	var t := Game.tuning
	velocity = velocity.bounce(n).normalized() * t.s2_exit_speed
	if light <= t.s2_damage:
		light = 0.0
		_die(Death.SHATTERED)
		return
	light -= t.s2_damage
	hurt_left = t.hurt_iframes
	Game.light_changed.emit(light, light_max)
	_hit(&"hurt")

func _drain_light(delta: float) -> void:
	if Game.debug_no_decay:
		return
	var t := Game.tuning
	var rate := t.decay * (t.focus_decay_mult if light_mode == LightMode.FOCUS else 1.0)
	light = maxf(light - rate * delta, 0.0)
	Game.light_changed.emit(light, light_max)
	if light <= 0.0:
		_die(Death.EXTINGUISHED)

func _die(cause: Death) -> void:
	death_cause = cause
	velocity = Vector2.ZERO
	_set_state(State.DYING)
	Game.light_changed.emit(light, light_max)
	if cause == Death.SHATTERED:
		Debris.spawn(get_parent(), global_position, STAR_COLOR, 18, 300.0, 6.0, true)
		_hit(&"shatter")

func _set_state(next: State) -> void:
	state = next
	_state_time = 0.0
	# 传送途中和死亡时不触发机关。
	collision_layer = 0 if next == State.WARP or next == State.DYING else Layers.PLAYER

func _update_stage() -> void:
	var s := stage_for(velocity.length(), stage)
	if s != stage:
		stage = s
		Game.speed_stage_changed.emit(stage)

func _hit(kind: StringName) -> void:
	Game.player_hit.emit(kind)

func _setup_visuals() -> void:
	# 小星自己发光，星体和拖尾不受暗处影响。
	material = Lighting.unshaded()
	_trail.use_parent_material = true
	var width := Curve.new()
	width.add_point(Vector2(0.0, 1.0))
	width.add_point(Vector2(1.0, 0.0))
	_trail.width_curve = width
	_trail.gradient = Gradient.new()
	var glow := Gradient.new()
	glow.set_color(0, Color(1.0, 0.86, 0.45, 0.45))
	glow.set_color(1, Color(1.0, 0.86, 0.45, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = glow
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = GLOW_TEX
	tex.height = GLOW_TEX
	_glow.texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow.material = mat
	_glow.scale = Vector2.ONE * CORONA / (GLOW_TEX * 0.5)

func _update_visuals() -> void:
	# 拖尾记录全局坐标，每帧换算成本地坐标交给 Line2D。
	if state == State.ACTIVE:
		_trail_points.push_front(global_position)
		if _trail_points.size() > TRAIL_POINTS:
			_trail_points.pop_back()
	elif not _trail_points.is_empty():
		_trail_points.pop_back()
	var local := PackedVector2Array()
	for p in _trail_points:
		local.append(p - global_position)
	_trail.points = local
	var c := Game.tuning.stage_color(stage)
	_trail.gradient.set_color(0, Color(c, 0.85))
	_trail.gradient.set_color(1, Color(c, 0.0))
	_glow.modulate.a = fade()
	queue_redraw()

## 星体和光的不透明度：出生淡入、熄灭淡出；碎裂和传送途中直接消失。
func fade() -> float:
	match state:
		State.SPAWN:
			return clampf(_state_time / SPAWN_TIME, 0.0, 1.0)
		State.WARP:
			return 0.0
		State.DYING:
			if death_cause == Death.SHATTERED:
				return 0.0
			return 1.0 - clampf(_state_time / DYING_TIME, 0.0, 1.0)
	return 1.0

func _draw() -> void:
	var a := fade()
	if a <= 0.0:
		return
	var warn := stage == 2 and state == State.ACTIVE
	var col := WARN_COLOR if warn and Time.get_ticks_msec() % 160 < 80 else STAR_COLOR
	if hurt_left > 0.0 and fmod(hurt_left, 0.1) < 0.05:
		a *= 0.35
	var r := RADIUS * 1.4 * (a if state == State.DYING else 1.0)
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(Vector2.from_angle(_spin + TAU * i / 10.0) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, Color(col, a))
	if shield:
		# 守夜人的盾：一圈淡蓝的光。
		draw_arc(Vector2.ZERO, RADIUS * 2.2, 0.0, TAU, 32, Color(SHIELD_COLOR, 0.6 * a), 2.0, true)
	if charged:
		# 科学家的虫洞给的冲劲：星体外一圈白光。
		draw_circle(Vector2.ZERO, RADIUS * 2.0, Color(1.0, 1.0, 1.0, 0.25 * a))
	if warn:
		# 阶段 2 预警：星体出现裂纹并闪红。
		var crack := Color(0.3, 0.05, 0.05, a)
		draw_polyline(PackedVector2Array([Vector2(-0.5, -0.2) * r, Vector2(-0.1, 0.05) * r, Vector2(0.15, -0.3) * r, Vector2(0.55, -0.1) * r]), crack, 1.5)
		draw_polyline(PackedVector2Array([Vector2(-0.1, 0.05) * r, Vector2(0.05, 0.5) * r]), crack, 1.5)
