extends Camera2D
## 跟随小星：按速度往前看，高速时拉远，撞击时震动。
## 拿到帮助的瞬间切一个特写：镜头切到帮助点、拉近、慢放一下，让玩家看清是谁帮了自己——
## 终章速度太快，一闪而过的话根本注意不到（这是实测出来的节奏问题）。

const LOOKAHEAD_TIME := 0.3
const LOOKAHEAD_MAX := 220.0
## 下标是速度阶段，0 不用。
const ZOOM_BY_STAGE := [1.0, 1.0, 0.97, 0.92, 0.86, 0.8]
const SHAKE_BY_HIT := {
	&"bump": 0.12,
	&"hurt": 0.6,
	&"bounce": 0.3,
	&"break": 0.95,
	&"smash": 0.9,
	&"stop": 0.35,
	&"shatter": 0.9,
	&"shield": 0.4,
	&"boss": 1.0,
	# 打碎敌人：比撞墙重、比死亡轻
	&"kill": 0.62,
}
const SHAKE_PX := 22.0
## 定帧（hit-stop）：撞上去的一瞬间整个世界停这么久（真实时间，秒），撞得越"实"停得越久。
## 反弹不停：走廊里连着弹几下时每下都停会一卡一卡的。
const HITSTOP_BY_HIT := {
	&"hurt": 0.07,
	&"break": 0.06,
	&"smash": 0.045,
	&"stop": 0.035,
	&"shield": 0.08,
	&"kill": 0.04,
}
## 定帧期间的时间倍率（不是 0：0 的话 delta 也是 0，有些逻辑会除以它）。
const HITSTOP_SCALE := 0.03
## 两次定帧至少隔多久（真实时间）：终章一路撞碎墙时不会卡成幻灯片。
const HITSTOP_GAP := 0.25
## 定向顿挫：镜头朝撞击方向（墙的反法线）猛推一下再弹回，比随机抖动更有"撞上了"的方向感。
const KICK_BY_HIT := {
	&"bump": 3.0,
	&"bounce": 7.0,
	&"hurt": 12.0,
	&"stop": 9.0,
	&"break": 11.0,
	&"smash": 9.0,
}
## 帮助特写：拉近到多少、定格多久（真实时间，秒）、慢放到多少。
const SPOT_ZOOM := 1.7
const SPOT_TIME := 1.15
const SPOT_SLOW := 0.35
## 死亡特写：比帮助特写更近、更慢、更短——玩家应该先看清"我怎么了"，然后马上重来。
const DEATH_ZOOM := 2.0
const DEATH_TIME := 0.5
const DEATH_SLOW := 0.28
## 熄灭（油尽灯枯）的版本：轻一点、久一点，配合"化开"的演出。
const DISSOLVE_ZOOM := 1.55
const DISSOLVE_TIME := 0.7
const DISSOLVE_SLOW := 0.45
## 铺路演出：镜头从玩家身上脱开、往赛道前方滑过去，顺便把镜头拉远看全跑道。
const SWEEP_ZOOM := 0.82
## 小人特写要推近，和铺路那种拉远的长镜头不一样。
const CINE_ZOOM := 1.6
const SWEEP_SLOW := 0.32

var _trauma := 0.0
var _look := Vector2.ZERO
## 特写还剩多久（真实时间）。
var _spot_left := 0.0
## 特写用多大的倍数。
var _spot_zoom := SPOT_ZOOM
## 特写框住的那个人（帮助点）。镜头框在他和小星中间，两人都看得见。
var _spot_help: Node2D
## 铺路演出：镜头脱开玩家滑到 to，滑完再回来。
var _sweep_from := Vector2.ZERO
var _sweep_to := Vector2.ZERO
var _sweep_total := 0.0
var _sweep_left := 0.0
var _sweep_zoom := SWEEP_ZOOM
## 定帧还剩多久、上一次定帧结束到现在多久（都是真实时间）。
var _stop_left := 0.0
var _since_stop := 99.0
## 定向顿挫的当前位移，指数回到 0。
var _kick := Vector2.ZERO

@onready var _player := get_parent() as Player

func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	Game.player_hit.connect(_on_player_hit)
	# 穿过虫洞直接切过去，不从地图这头平移到那头。
	Game.warped.connect(reset_smoothing)
	Game.help_triggered.connect(_on_help_triggered)
	Game.player_dying.connect(_on_player_dying)

func _physics_process(delta: float) -> void:
	# delta 被 time_scale 缩放过；特写的时长按真实时间算。
	var real := delta / maxf(Engine.time_scale, 0.001)
	if _sweep_left > 0.0:
		_sweep(real)
		return
	if _spot_left > 0.0:
		_spot_left -= real
		if _spot_left > 0.0:
			_spot(real)
			return
		_end_spot()
	# 定帧按物理帧数计时（每帧 = 1/物理帧率 的真实时间）：不能用 delta ÷ time_scale——
	# 定帧开始的那一帧，delta 是按旧倍率算的，除以新倍率会算出半秒，定帧当帧就结束了。
	var tick := 1.0 / Engine.physics_ticks_per_second
	_since_stop += tick
	if _stop_left > 0.0:
		_stop_left -= tick
		if _stop_left <= 0.0:
			_end_hitstop()
	var target := (_player.velocity * LOOKAHEAD_TIME).limit_length(LOOKAHEAD_MAX)
	_look = _look.lerp(target, 1.0 - exp(-3.0 * delta))
	position = _look
	var z: float = ZOOM_BY_STAGE[_player.stage]
	zoom = zoom.lerp(Vector2(z, z), 1.0 - exp(-2.0 * delta))
	# 抖动和顿挫按真实时间衰减：定帧期间镜头也照样在抖，"停住"的只是世界。
	_trauma = maxf(_trauma - 1.5 * tick, 0.0)
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-16.0 * tick))
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_PX * _trauma * _trauma + _kick

func _start_hitstop(time: float) -> void:
	if time <= 0.0 or _since_stop < HITSTOP_GAP or _spot_left > 0.0 or _sweep_left > 0.0:
		return
	if not is_equal_approx(Engine.time_scale, 1.0):
		return  # 别的慢放（暂停之外的演出）正在进行，不去动它
	_stop_left = time
	Engine.time_scale = HITSTOP_SCALE

func _end_hitstop() -> void:
	_stop_left = 0.0
	_since_stop = 0.0
	if is_equal_approx(Engine.time_scale, HITSTOP_SCALE):
		Engine.time_scale = 1.0

## 谁帮了忙就把镜头切到谁身上，同时慢放。
func _on_help_triggered(role: StringName) -> void:
	var help := _help_point(role)
	if help == null:
		return
	_cancel_hitstop()
	_spot_help = help
	_spot_zoom = SPOT_ZOOM
	_spot_left = SPOT_TIME
	Engine.time_scale = SPOT_SLOW

## 小星死了：就着它倒下的地方拉近、慢放。熄灭（油尽灯枯）轻一点，碎掉重一点。
func _on_player_dying(_pos: Vector2, cause: int) -> void:
	_cancel_hitstop()
	_spot_help = null
	if cause == Player.Death.EXTINGUISHED:
		_spot_zoom = DISSOLVE_ZOOM
		_spot_left = DISSOLVE_TIME
		Engine.time_scale = DISSOLVE_SLOW
	else:
		_spot_zoom = DEATH_ZOOM
		_spot_left = DEATH_TIME
		Engine.time_scale = DEATH_SLOW

## 已经触发、职业对得上的那个帮助点（每个职业每段赛道只有一个）。
func _help_point(role: StringName) -> Node2D:
	for node in get_tree().get_nodes_in_group(&"help_point"):
		var help := node as HelpPoint
		if help != null and help.triggered and help.role == String(role):
			return help
	return null

## 特写期间：镜头框在帮助点和小星中间，拉近，不留前视。
func _spot(real: float) -> void:
	var focus := _player.global_position
	if is_instance_valid(_spot_help):
		focus = (_spot_help.global_position + _player.global_position) * 0.5
	var local := focus - _player.global_position
	position = position.lerp(local, 1.0 - exp(-12.0 * real))
	zoom = zoom.lerp(Vector2(_spot_zoom, _spot_zoom), 1.0 - exp(-8.0 * real))
	offset = Vector2.ZERO
	_look = position

func _end_spot() -> void:
	_spot_left = 0.0
	Engine.time_scale = 1.0
	reset_smoothing()

## 铺路演出：镜头从玩家身上脱开、沿赛道往前（往左）滑过去，一边滑一边拉远，
## 让玩家看清这一段跑道是怎么被点亮的。滑完自动回到跟随。
## 正在做特写/铺路演出时返回 true（别的新演出要等它结束）。
func is_sweeping() -> bool:
	return _sweep_left > 0.0

func sweep(to_world: Vector2, time := 1.3, zoom_to := SWEEP_ZOOM) -> void:
	if _sweep_left > 0.0:
		return
	_cancel_hitstop()
	_sweep_from = _player.global_position
	_sweep_to = to_world
	_sweep_total = maxf(time, 0.2)
	_sweep_left = _sweep_total
	_sweep_zoom = zoom_to
	# 推近的特写直接切到位（1 帧内到位），拉远的长镜头才慢慢走
	if zoom_to >= 1.0:
		zoom = Vector2(zoom_to, zoom_to)
	Engine.time_scale = SWEEP_SLOW

func _sweep(real: float) -> void:
	_sweep_left -= real
	var k := 1.0 - clampf(_sweep_left / _sweep_total, 0.0, 1.0)
	var eased := smoothstep(0.0, 1.0, k)
	var world := _sweep_from.lerp(_sweep_to, eased)
	position = world - _player.global_position
	zoom = zoom.lerp(Vector2(_sweep_zoom, _sweep_zoom), 1.0 - exp(-6.0 * real))
	offset = Vector2.ZERO
	_look = position
	if _sweep_left <= 0.0:
		_sweep_left = 0.0
		Engine.time_scale = 1.0
		reset_smoothing()

## 暂停时把定帧收掉：暂停菜单也走 Engine.time_scale，不收的话菜单动画会跟着变慢。
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_cancel_hitstop()

## 有更大的演出（特写、铺路）要接管时间：定帧直接让位，时间倍率交给它们去设。
func _cancel_hitstop() -> void:
	if _stop_left > 0.0:
		_stop_left = 0.0
		_since_stop = 0.0
		Engine.time_scale = 1.0

## 镜头被删掉（换场景、死亡重载）时把慢放收回来，别让结局画面一起变慢。
func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _on_player_hit(kind: StringName) -> void:
	_trauma = minf(_trauma + SHAKE_BY_HIT.get(kind, 0.0), 1.0)
	var kick: float = KICK_BY_HIT.get(kind, 0.0)
	if kick > 0.0 and _player.last_normal != Vector2.ZERO:
		_kick = -_player.last_normal * kick
	_start_hitstop(HITSTOP_BY_HIT.get(kind, 0.0))
