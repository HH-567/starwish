extends Node
## 音效：把 Game 上的信号接到几个音效上（docs/state-machines.md 第 15 节：HUD、音效只听信号）。
## 音乐还没有，这里只管一次性音效。
## Web 上音频要等第一次点击/按键才能响（浏览器的自动播放策略），所以第一次输入之前一律不播；
## Game._input 收到第一个按键/点击时调 unlock()。
## 同一个音效有冷却时间，连着撞墙时不会糊成一片。

const STREAMS := {
	&"rescue": preload("res://audio/rescue.wav"),
	&"hit": preload("res://audio/hit.wav"),
	&"burn": preload("res://audio/burn.wav"),
	&"break": preload("res://audio/break.wav"),
	&"warp": preload("res://audio/warp.wav"),
	&"help": preload("res://audio/help.wav"),
	&"clear": preload("res://audio/clear.wav"),
	&"death": preload("res://audio/death.wav"),
	&"boss": preload("res://audio/boss.wav"),
	&"ending": preload("res://audio/ending.wav"),
}
## 同一种音效的最短间隔，秒。
const COOLDOWN := {
	&"hit": 0.12,
	&"rescue": 0.15,
	&"burn": 0.1,
	&"break": 0.1,
	&"warp": 0.15,
	&"help": 0.2,
}
## 同时能响几个（互相盖住时轮流用）。
const VOICES := 6
## 整体音量，dB。
const VOLUME := -6.0

## 每个音效的相对音量（dB）：撞墙这种高频事件压低，救人/过关抬起来。
const LEVELS := {
	&"hit": -7.0,
	&"break": -2.0,
	&"burn": -5.0,
	&"rescue": 0.0,
	&"help": -3.0,
	&"warp": -3.0,
	&"clear": 0.0,
	&"death": 0.0,
	&"boss": -1.0,
	&"ending": 0.0,
}
## 同一个音效重复播时，在 ±这个范围里随机微调音高，避免机械重复感。
const PITCH_JITTER := 0.06

## 背景音乐：两路播放器交叉淡化。文件放 res://audio/bgm/<id>.ogg，没有就静音（不会报错）。
const BGM_DIR := "res://audio/bgm/"
const BGM_FADE := 1.4
## 有音乐时整体压到这个音量，给音效让路。
const BGM_DB := -14.0
## 暂停/死亡时再压低多少。
const BGM_DUCK_DB := -10.0

## 第一次输入之前为真：不播。
var locked := true
## 最近播过的那个音效，测试用。
var last_played := &""
## 一共播过多少次，测试用。
var count := 0
## 游戏内的秒数：冷却按它算，不按墙上时钟——无头测试用 --fixed-fps 跑的时候，墙上时钟和游戏时间对不上。
var now := 0.0

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_time := {}
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _bgm_active: AudioStreamPlayer
var _bgm_current := &""
var _ducked := false
var _bgm_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = VOLUME
		add_child(player)
		_players.append(player)
	_bgm_a = AudioStreamPlayer.new()
	_bgm_b = AudioStreamPlayer.new()
	for p: AudioStreamPlayer in [_bgm_a, _bgm_b]:
		p.volume_db = -80.0
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
	_bgm_active = _bgm_a
	Game.player_hit.connect(_on_hit)
	Game.npc_rescued.connect(func(_id: String) -> void: play(&"rescue"))
	Game.vine_burnt.connect(func(_id: String) -> void: play(&"burn"))
	Game.wall_broken.connect(func(_id: String) -> void: play(&"break"))
	Game.warped.connect(func() -> void: play(&"warp"))
	Game.help_triggered.connect(func(_role: StringName) -> void: play(&"help"))
	Game.chapter_cleared.connect(func(_id: StringName) -> void: play(&"clear"))
	# 死亡音效跟"开始死"同步，不是跟"死完"——player_died 是动画播完之后才发的，
	# 挂在它上面会变成"动画放完才响"。
	Game.player_dying.connect(func(_pos: Vector2, _cause: int) -> void: play(&"death"))
	Game.boss_state_changed.connect(_on_boss_state)

func _process(delta: float) -> void:
	now += delta

## 第一次按键/点击：Web 上从这里开始才能出声。
func unlock() -> void:
	locked = false

func has(id: StringName) -> bool:
	return STREAMS.has(id)

## 播一个音效。locked 时什么都不做；冷却内的重复触发也丢掉。
func play(id: StringName) -> void:
	if locked or not STREAMS.has(id):
		return
	if now - float(_last_time.get(id, -999.0)) < float(COOLDOWN.get(id, 0.05)):
		return
	_last_time[id] = now
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = STREAMS[id]
	player.volume_db = VOLUME + float(LEVELS.get(id, 0.0))
	player.pitch_scale = 1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER)
	player.play()
	last_played = id
	count += 1

## 背景音乐：换曲子时交叉淡化。优先 .ogg，没有就找 .wav；都没有就静默跳过（还没交付）。
func play_bgm(id: StringName) -> void:
	if id == _bgm_current:
		return
	var stream: AudioStream = null
	for ext: String in [".ogg", ".wav"]:
		var path := BGM_DIR + String(id) + ext
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
			if stream != null:
				break
	if stream == null:
		return
	# WAV 需要自己开循环；ogg 在导入时设了 loop。
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.get_length() * wav.mix_rate
	_bgm_current = id
	var next := _bgm_b if _bgm_active == _bgm_a else _bgm_a
	var prev := _bgm_active
	next.stream = stream
	next.volume_db = -80.0
	next.play()
	_bgm_active = next
	var target := BGM_DB + (BGM_DUCK_DB if _ducked else 0.0)
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween().set_parallel(true)
	_bgm_tween.tween_property(next, "volume_db", target, BGM_FADE)
	_bgm_tween.tween_property(prev, "volume_db", -80.0, BGM_FADE)
	await _bgm_tween.finished
	if prev != next:
		prev.stop()

## 暂停 / 死亡时把音乐压低，恢复时抬回来。
func set_ducked(value: bool) -> void:
	_ducked = value
	if _bgm_active == null or _bgm_current == &"":
		return
	_bgm_active.volume_db = BGM_DB + (BGM_DUCK_DB if value else 0.0)

## 撞墙：擦墙和反弹不响，免得每帧都在响；受伤和轻撞响一下。
func _on_hit(kind: StringName) -> void:
	if kind == &"bump" or kind == &"hurt":
		play(&"hit")

func _on_boss_state(state: int) -> void:
	if state == Boss.State.EMERGE:
		play(&"boss")
		play_bgm(&"chase")
