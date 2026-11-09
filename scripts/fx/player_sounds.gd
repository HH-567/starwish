class_name PlayerSounds
extends Node
## 小星身上跟着状态连续变化的声音：挂在 Player 下面，Player._setup_visuals 里加。
## - 风声：速度越快越响、越尖。阶段 1 慢慢走时听不见，阶段 4 往上呼呼的——不看拖尾颜色也知道自己多快。
## - 心跳：亮度低于 low_light_ratio 时开始，越暗跳得越快。和光环闪红同一个阈值。

## 风声从多快开始有、到多快最响（px/s）。阶段 2 下限 220，阶段 4 下限 620。
const WIND_FROM := 200.0
const WIND_FULL := 900.0
## 心跳间隔：刚到阈值时 / 快灭时（秒）。
const BEAT_SLOW := 1.0
const BEAT_FAST := 0.5

var _beat_left := 0.0

@onready var _player := get_parent() as Player

func _physics_process(delta: float) -> void:
	if _player == null or _player.state != Player.State.ACTIVE:
		return
	var speed := _player.velocity.length()
	var k := clampf((speed - WIND_FROM) / (WIND_FULL - WIND_FROM), 0.0, 1.0)
	if k > 0.0:
		Audio.hold(&"wind", &"wind", k * k * 0.9 + 0.1 * k, 0.7 + 0.6 * k)
	var t := Game.tuning
	var low := _player.light_max * t.low_light_ratio
	if _player.light < low and not Game.debug_no_decay:
		_beat_left -= delta
		if _beat_left <= 0.0:
			Audio.play(&"heart")
			_beat_left = lerpf(BEAT_FAST, BEAT_SLOW, clampf(_player.light / maxf(low, 0.01), 0.0, 1.0))
	else:
		_beat_left = 0.0
