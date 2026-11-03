extends Camera2D
## 跟随小星：按速度往前看，高速时拉远，撞击时震动。

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

var _trauma := 0.0
var _look := Vector2.ZERO

@onready var _player := get_parent() as Player

func _ready() -> void:
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	Game.player_hit.connect(_on_player_hit)
	# 穿过虫洞直接切过去，不从地图这头平移到那头。
	Game.warped.connect(reset_smoothing)

func _physics_process(delta: float) -> void:
	var target := (_player.velocity * LOOKAHEAD_TIME).limit_length(LOOKAHEAD_MAX)
	_look = _look.lerp(target, 1.0 - exp(-3.0 * delta))
	position = _look
	var z: float = ZOOM_BY_STAGE[_player.stage]
	zoom = zoom.lerp(Vector2(z, z), 1.0 - exp(-2.0 * delta))
	_trauma = maxf(_trauma - 1.5 * delta, 0.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_PX * _trauma * _trauma

func _on_player_hit(kind: StringName) -> void:
	_trauma = minf(_trauma + SHAKE_BY_HIT.get(kind, 0.0), 1.0)
