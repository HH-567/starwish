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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.volume_db = VOLUME
		add_child(player)
		_players.append(player)
	Game.player_hit.connect(_on_hit)
	Game.npc_rescued.connect(func(_id: String) -> void: play(&"rescue"))
	Game.vine_burnt.connect(func(_id: String) -> void: play(&"burn"))
	Game.wall_broken.connect(func(_id: String) -> void: play(&"break"))
	Game.warped.connect(func() -> void: play(&"warp"))
	Game.help_triggered.connect(func(_role: StringName) -> void: play(&"help"))
	Game.chapter_cleared.connect(func(_id: StringName) -> void: play(&"clear"))
	Game.player_died.connect(func(_cause: int) -> void: play(&"death"))
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
	player.play()
	last_played = id
	count += 1

## 撞墙：擦墙和反弹不响，免得每帧都在响；受伤和轻撞响一下。
func _on_hit(kind: StringName) -> void:
	if kind == &"bump" or kind == &"hurt":
		play(&"hit")

func _on_boss_state(state: int) -> void:
	if state == Boss.State.EMERGE:
		play(&"boss")
