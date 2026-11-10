extends Node
## 音效：把 Game 上的信号接到音效上（docs/state-machines.md 第 15 节：HUD、音效只听信号）。
## 三种播法：
##   play(id)          不带位置的一次性音效（小星自己的事：撞墙、捡星星、切光……）
##   play_at(id, pos)  带位置的一次性音效（影鬼、流星、小人的哭声）：离得远就小声、偏左偏右听得出来
##   hold(key, id, …)  循环音（风声、照醒小人、影藤在烧）：每帧调用一次"续命"，不调了就自己淡出
## Web 上音频要等第一次点击/按键才能响（浏览器的自动播放策略），所以第一次输入之前一律不播；
## Game._input 收到第一个按键/点击时调 unlock()。
## 同一个音效有冷却时间，连着撞墙时不会糊成一片。
## 新音效由 tools/sfx_synth.py 合成，改那边再重新导入。

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
	# 下面这些是 tools/sfx_synth.py 合成的
	&"bounce": preload("res://audio/bounce.wav"),
	&"smash": preload("res://audio/smash.wav"),
	&"shatter": preload("res://audio/shatter.wav"),
	&"stop": preload("res://audio/stop.wav"),
	&"shard": preload("res://audio/shard.wav"),
	&"warn": preload("res://audio/warn.wav"),
	&"gear": preload("res://audio/gear.wav"),
	&"focus": preload("res://audio/focus.wav"),
	&"scatter": preload("res://audio/scatter.wav"),
	&"aim": preload("res://audio/aim.wav"),
	&"shot": preload("res://audio/shot.wav"),
	&"meteor_warn": preload("res://audio/meteor_warn.wav"),
	&"meteor": preload("res://audio/meteor.wav"),
	&"checkpoint": preload("res://audio/checkpoint.wav"),
	&"door": preload("res://audio/door.wav"),
	&"accel": preload("res://audio/accel.wav"),
	&"ui": preload("res://audio/ui.wav"),
	&"heart": preload("res://audio/heart.wav"),
	&"cry": preload("res://audio/cry.wav"),
	&"shield": preload("res://audio/shield.wav"),
}
## 循环音（hold 用），导入后在这里开循环。
const LOOPS := {
	&"wind": preload("res://audio/wind.wav"),
	&"wake": preload("res://audio/wake.wav"),
	&"crackle": preload("res://audio/crackle.wav"),
}
## 同一种音效的最短间隔，秒。
const COOLDOWN := {
	&"hit": 0.12,
	&"rescue": 0.15,
	&"burn": 0.1,
	&"break": 0.1,
	&"warp": 0.15,
	&"help": 0.2,
	&"bounce": 0.07,
	&"smash": 0.06,
	&"shatter": 0.05,
	&"stop": 0.15,
	&"shard": 0.04,
	&"warn": 0.5,
	&"gear": 0.35,
	&"focus": 0.06,
	&"scatter": 0.06,
	&"shot": 0.05,
	&"accel": 0.25,
	&"ui": 0.04,
	&"heart": 0.3,
	&"cry": 0.0,
	&"aim": 0.0,
	&"meteor_warn": 0.0,
	&"meteor": 0.0,
}
## 同时能响几个（互相盖住时轮流用）。
const VOICES := 8
const VOICES_2D := 10
## 整体音量，dB。
const VOLUME := -6.0

## 每个音效的相对音量（dB）：撞墙这种高频事件压低，救人/过关抬起来。
## 合成的那批在 sfx_synth.py 里已经按用途归一化过响度，这里只做微调。
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
	&"bounce": -2.0,
	&"smash": 0.0,
	&"shatter": -1.0,
	&"stop": -1.0,
	&"shard": -1.0,
	&"warn": -1.0,
	&"gear": -3.0,
	&"focus": -2.0,
	&"scatter": -2.0,
	&"aim": 0.0,
	&"shot": 0.0,
	&"meteor_warn": 0.0,
	&"meteor": 0.0,
	&"checkpoint": 0.0,
	&"door": 0.0,
	&"accel": -1.0,
	&"ui": -4.0,
	&"heart": -2.0,
	&"cry": -1.0,
	&"shield": 0.0,
}
## 带位置的音效：多远之外听不见、衰减曲线。屏幕半宽约 640 px。
const HEAR_PX := 1100.0
const ATTENUATION := 1.4
## 循环音没人续命之后多久淡完，秒。
const LOOP_FADE := 0.25
## 连着捡小星星：窗口内每多捡一颗升一级（五声音阶，听起来是一串往上走的音）。
const SHARD_WINDOW := 1.4
const SHARD_STEPS := [0, 2, 4, 7, 9, 12, 14, 16]

## 音量（0..1）→ dB 偏移，-60 dB 视为静音。
func _volume_db(v: float) -> float:
	return -60.0 if v <= 0.001 else linear_to_db(v)

## 设置里调完音量后立刻生效（已经在播的 BGM / 音效也要跟着变）。
func apply_volume() -> void:
	if _bgm_active != null and is_instance_valid(_bgm_active):
		_bgm_active.volume_db = BGM_DB + (BGM_DUCK_DB if _ducked else 0.0) + _volume_db(Save.music_volume)
	for p in _players:
		if p != null and p.playing:
			p.volume_db = VOLUME + _volume_db(Save.sfx_volume)

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
var _players_2d: Array[AudioStreamPlayer2D] = []
var _next_2d := 0
var _last_time := {}
## 循环音：key → {player, id, target_db, alive}
var _loops := {}
var _stage := 1
var _shard_combo := 0
var _shard_at := -100.0
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
	for i in VOICES_2D:
		var p2 := AudioStreamPlayer2D.new()
		p2.max_distance = HEAR_PX
		p2.attenuation = ATTENUATION
		add_child(p2)
		_players_2d.append(p2)
	for id: StringName in LOOPS:
		var wav := LOOPS[id] as AudioStreamWAV
		if wav != null:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	_bgm_a = AudioStreamPlayer.new()
	_bgm_b = AudioStreamPlayer.new()
	for p: AudioStreamPlayer in [_bgm_a, _bgm_b]:
		p.volume_db = -80.0
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
	_bgm_active = _bgm_a
	Game.player_hit.connect(_on_hit)
	Game.speed_stage_changed.connect(_on_stage)
	Game.npc_rescued.connect(func(_id: String) -> void: play(&"rescue"))
	Game.vine_burnt.connect(func(_id: String) -> void: play(&"burn"))
	Game.wall_broken.connect(func(_id: String) -> void: play(&"break"))
	Game.warped.connect(func() -> void: play(&"warp"))
	Game.help_triggered.connect(func(_role: StringName) -> void: play(&"help"))
	Game.chapter_cleared.connect(func(_id: StringName) -> void: play(&"clear"))
	Game.checkpoint_reached.connect(func(_id: String) -> void: play(&"checkpoint"))
	# 死亡音效跟"开始死"同步，不是跟"死完"——player_died 是动画播完之后才发的，
	# 挂在它上面会变成"动画放完才响"。死的时候顺便把音乐压低，下一章/复活时 Chapter 抬回来。
	Game.player_dying.connect(func(_pos: Vector2, _cause: int) -> void:
		play(&"death")
		set_ducked(true))
	Game.boss_state_changed.connect(_on_boss_state)

func _process(delta: float) -> void:
	now += delta
	_update_loops(delta)

## 第一次按键/点击：Web 上从这里开始才能出声。
func unlock() -> void:
	locked = false

func has(id: StringName) -> bool:
	return STREAMS.has(id) or LOOPS.has(id)

## 冷却内、没解锁、没这个音效：返回 false。通过时记下时间。
func _accept(id: StringName) -> bool:
	if locked or not STREAMS.has(id):
		return false
	if now - float(_last_time.get(id, -999.0)) < float(COOLDOWN.get(id, 0.05)):
		return false
	_last_time[id] = now
	last_played = id
	count += 1
	return true

func _db(id: StringName) -> float:
	return VOLUME + float(LEVELS.get(id, 0.0)) + _volume_db(Save.sfx_volume)

## 播一个音效。locked 时什么都不做；冷却内的重复触发也丢掉。
## jitter 为假时不加随机音高（按音阶走的音效，加了会跑调）。
func play(id: StringName, pitch_mul := 1.0, jitter := true) -> void:
	if not _accept(id):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = STREAMS[id]
	player.volume_db = _db(id)
	player.pitch_scale = pitch_mul * ((1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER)) if jitter else 1.0)
	player.play()

## 在世界坐标 pos 播一个音效：离镜头越远越小声，超过 HEAR_PX 干脆不播（不占声部）。
## 返回用到的播放器（瞄准声这种要中途掐掉的，调用方拿去 stop()）；没播返回 null。
func play_at(id: StringName, pos: Vector2, pitch_mul := 1.0) -> AudioStreamPlayer2D:
	var cam := get_viewport().get_camera_2d()
	if cam != null and cam.get_screen_center_position().distance_to(pos) > HEAR_PX:
		return null
	if not _accept(id):
		return null
	var player := _players_2d[_next_2d]
	_next_2d = (_next_2d + 1) % _players_2d.size()
	player.stream = STREAMS[id]
	player.volume_db = _db(id)
	player.pitch_scale = pitch_mul * (1.0 + randf_range(-PITCH_JITTER, PITCH_JITTER) * 0.5)
	player.global_position = pos
	player.play()
	return player

## 循环音续命：每帧调一次。volume 是 0..1（乘在这个循环音自己的音量上），pitch 是音高倍率。
## 带 pos 就是带位置的循环音（小人、影藤），不带就是小星自己的（风声）。
## 某个 key 一帧没被调用，它就在 LOOP_FADE 秒内淡出并停掉。
func hold(key: StringName, id: StringName, volume := 1.0, pitch := 1.0, pos: Variant = null) -> void:
	if locked or not LOOPS.has(id):
		return
	var loop: Dictionary = _loops.get(key, {})
	if loop.is_empty():
		var player: Node = AudioStreamPlayer2D.new() if pos != null else AudioStreamPlayer.new()
		if player is AudioStreamPlayer2D:
			(player as AudioStreamPlayer2D).max_distance = HEAR_PX
			(player as AudioStreamPlayer2D).attenuation = ATTENUATION
		player.set(&"stream", LOOPS[id])
		player.set(&"volume_db", -60.0)
		add_child(player)
		player.call(&"play", randf() * (LOOPS[id] as AudioStream).get_length())
		loop = {"player": player, "level": 0.0}
		_loops[key] = loop
	loop["target"] = clampf(volume, 0.0, 1.0)
	loop["alive"] = true
	var p: Node = loop["player"]
	p.set(&"pitch_scale", maxf(pitch, 0.05))
	if pos != null and p is AudioStreamPlayer2D:
		(p as AudioStreamPlayer2D).global_position = pos

func _update_loops(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	var dead: Array[StringName] = []
	for key: StringName in _loops:
		var loop: Dictionary = _loops[key]
		var target: float = loop.get("target", 0.0) if loop.get("alive", false) else 0.0
		var level: float = loop["level"]
		# 起音快一点、收音慢一点；没人续命就往 0 走。
		var rate := (1.0 / 0.08) if target > level else (1.0 / LOOP_FADE)
		level = move_toward(level, target, rate * real)
		loop["level"] = level
		loop["alive"] = false
		var p: Node = loop["player"]
		p.set(&"volume_db", VOLUME + _volume_db(level) + _volume_db(Save.sfx_volume))
		if level <= 0.0 and target <= 0.0:
			dead.append(key)
	for key in dead:
		(_loops[key]["player"] as Node).queue_free()
		_loops.erase(key)

## 正在响的循环音个数，测试用。
func loop_count() -> int:
	return _loops.size()

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
	# WAV 需要自己开循环；ogg 一般靠导入参数，这里也兜底开上（新做的 BGM 全是 ogg）。
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.get_length() * wav.mix_rate
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_bgm_current = id
	var next := _bgm_b if _bgm_active == _bgm_a else _bgm_a
	var prev := _bgm_active
	next.stream = stream
	next.volume_db = -80.0
	next.play()
	_bgm_active = next
	var target := BGM_DB + (BGM_DUCK_DB if _ducked else 0.0) + _volume_db(Save.music_volume)
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
	if value == _ducked:
		return
	_ducked = value
	if _bgm_active == null or _bgm_current == &"":
		return
	if _bgm_tween != null and _bgm_tween.is_valid():
		# 正在交叉淡化：直接收尾（旧曲停掉），新曲按新的目标音量放。
		_bgm_tween.kill()
		var other := _bgm_b if _bgm_active == _bgm_a else _bgm_a
		other.stop()
		other.volume_db = -80.0
	_bgm_active.volume_db = BGM_DB + (BGM_DUCK_DB if value else 0.0) + _volume_db(Save.music_volume)

## 撞墙和其他碰撞：每种一个声音。擦墙不发信号，所以贴墙滑行时是安静的。
func _on_hit(kind: StringName) -> void:
	match kind:
		&"bump", &"hurt":
			play(&"hit")
		&"bounce":
			# 越快弹得越脆
			play(&"bounce", 1.0 if _stage <= 3 else 1.12)
		&"smash":
			play(&"smash")
		&"stop":
			play(&"stop")
		&"shield":
			play(&"shield")

## 换档：掉进阶段 2 响预警；升到 3、4（能弹墙了）和 5（能撞碎了）各响一声往上走的风。
func _on_stage(stage: int) -> void:
	var prev := _stage
	_stage = stage
	if stage == 2 and prev == 1:
		play(&"warn")
	elif stage > prev and stage >= 3:
		play(&"gear", [1.0, 1.0, 1.0, 1.0, 1.12, 1.26][stage])

## 捡到小星星：连着捡音越来越高。
func play_shard() -> void:
	_shard_combo = _shard_combo + 1 if now - _shard_at < SHARD_WINDOW else 0
	_shard_at = now
	var step: int = SHARD_STEPS[mini(_shard_combo, SHARD_STEPS.size() - 1)]
	play(&"shard", pow(2.0, step / 12.0), false)

func _on_boss_state(state: int) -> void:
	if state == Boss.State.EMERGE:
		play(&"boss")
		play_bgm(&"chase")
