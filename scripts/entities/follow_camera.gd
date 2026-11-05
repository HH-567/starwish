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
	&"break": 0.5,
	&"smash": 0.45,
	&"stop": 0.35,
	&"shatter": 0.9,
	&"shield": 0.4,
	&"boss": 1.0,
}
const SHAKE_PX := 14.0
## 帮助特写：拉近到多少、定格多久（真实时间，秒）、慢放到多少。
const SPOT_ZOOM := 1.7
const SPOT_TIME := 1.15
const SPOT_SLOW := 0.35
## 死亡特写：比帮助特写更近、更慢、更短——玩家应该先看清"我碎了"，然后马上重来。
const DEATH_ZOOM := 2.0
const DEATH_TIME := 0.5
const DEATH_SLOW := 0.28

var _trauma := 0.0
var _look := Vector2.ZERO
## 特写还剩多久（真实时间）。
var _spot_left := 0.0
## 特写用多大的倍数。
var _spot_zoom := SPOT_ZOOM
## 特写框住的那个人（帮助点）。镜头框在他和小星中间，两人都看得见。
var _spot_help: Node2D

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
	var real := delta / maxf(Engine.time_scale, 0.01)
	if _spot_left > 0.0:
		_spot_left -= real
		if _spot_left > 0.0:
			_spot(real)
			return
		_end_spot()
	var target := (_player.velocity * LOOKAHEAD_TIME).limit_length(LOOKAHEAD_MAX)
	_look = _look.lerp(target, 1.0 - exp(-3.0 * delta))
	position = _look
	var z: float = ZOOM_BY_STAGE[_player.stage]
	zoom = zoom.lerp(Vector2(z, z), 1.0 - exp(-2.0 * delta))
	_trauma = maxf(_trauma - 1.5 * delta, 0.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_PX * _trauma * _trauma

## 谁帮了忙就把镜头切到谁身上，同时慢放。
func _on_help_triggered(role: StringName) -> void:
	var help := _help_point(role)
	if help == null:
		return
	_spot_help = help
	_spot_zoom = SPOT_ZOOM
	_spot_left = SPOT_TIME
	Engine.time_scale = SPOT_SLOW

## 小星碎了：就着它碎的地方拉近、慢放。碎片是在关卡里播的，镜头跟着玩家走，正好框住。
func _on_player_dying(_pos: Vector2) -> void:
	_spot_help = null
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

## 镜头被删掉（换场景、死亡重载）时把慢放收回来，别让结局画面一起变慢。
func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _on_player_hit(kind: StringName) -> void:
	_trauma = minf(_trauma + SHAKE_BY_HIT.get(kind, 0.0), 1.0)
