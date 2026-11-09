extends Node
## 全局：游戏流程、数值、跨系统信号、输入映射、调试键（docs/state-machines.md 第 1、15 节）。
## 从标题进来时，章节和终章由这里加载，进度按时写盘。直接运行某个章节或终章场景（F6、测试）时不读也不写存档，
## 死亡和按 R 直接重载当前场景。

signal speed_stage_changed(stage: int)
signal light_changed(value: float, max_value: float)
signal player_hit(kind: StringName)
## 小星刚开始死亡演出（还没重载场景）。镜头靠它切特写；cause 用 Player.Death。
signal player_dying(pos: Vector2, cause: int)
## 终章里点灯的人把赛道加速带铺出来的那一刻。
signal road_light(pos: Vector2)
signal player_died(cause: int)
signal npc_rescued(id: String)
signal difficulty_changed(level: int)
signal vine_burnt(id: String)
signal wall_broken(id: String)
signal checkpoint_reached(id: String)
signal chapter_cleared(chapter_id: StringName)
signal warped
signal help_triggered(role: StringName)
signal boss_state_changed(state: int)
## 影鬼被打掉了。reason：&"charge"（小星撞散）或 &"shot"（弹幕打中）。
signal enemy_killed(reason: StringName)
signal debug_changed

enum Flow { BOOT, TITLE, LOADING, PLAYING, CHASE, PAUSED, RESPAWN, CLEAR, ENDING }

const _ACTIONS := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"light_scatter": [KEY_SPACE],
	"light_focus": [KEY_SHIFT],
	"reset": [KEY_R],
	"pause": [KEY_ESCAPE],
}
const _MOUSE_ACTIONS := {
	"light_scatter": MOUSE_BUTTON_LEFT,
	"light_focus": MOUSE_BUTTON_RIGHT,
}

const TUNING_PATH := "res://data/tuning.tres"
## 章节顺序。四章正式章节都在这里；测试关只留在 tests 里当样本，不进这张表。
## 终章按倒序接上各章的回程赛道。
const CHAPTERS := [
	[&"ch0", "res://scenes/levels/ch0_fall.tscn"],
	[&"ch1", "res://scenes/levels/ch1_vine.tscn"],
	[&"ch2", "res://scenes/levels/ch2_mirror.tscn"],
	[&"ch3", "res://scenes/levels/ch3_crack.tscn"],
	[&"ch4", "res://scenes/levels/ch4_pair.tscn"],
]
## 终章：最后一章通关后进。它不在章节表里，存档里的 chapter 记成 "finale"。
const FINALE_ID := "finale"
const FINALE_SCENE := "res://scenes/levels/finale.tscn"
## 全游戏一共 12 个人，全救出来才有隐藏结局。tests/test_full 检查它等于章节表里各章小人的总数，
## 也检查 12 个职业不重不漏。
const NPC_TOTAL := 12
const TITLE_SCENE := "res://scenes/ui/title.tscn"
const ENDING_SCENE := "res://scenes/ui/ending.tscn"
const PAUSE_SCENE := "res://scenes/ui/pause_menu.tscn"
const FADE_TIME := 0.35
## 进了出口之后停多久再切到下一章。
const CLEAR_TIME := 0.8

var tuning: Tuning = preload(TUNING_PATH)
var debug_no_decay := false
## 测试用：关掉影鬼的行动，免得它们打乱"亮度应该是多少"这类断言。
var debug_no_enemies := false
## 测试用：把终章迷宫的墙抹平，只验追逐/加速带/结局分支（迷宫本身用 probe_maze 验）。
var debug_flat_maze := false
var debug_panel := true
## 直接运行关卡或测试时一开始就是 PLAYING；从标题进来时 Title 调 enter_title()。
var flow := Flow.PLAYING
## 章节顺序表，测试可以换成自己的。
var chapters: Array = CHAPTERS
## 当前章节在表里的位置，-1 = 不是从标题进来的。
var chapter_index := -1
## 从标题开始或继续之后才写存档。
var persist := false
## 正在演的结局：main 或 hidden。
var ending := &""

var _booted := false
var _fade: ColorRect
var _pause_menu: CanvasLayer
var _flow_before_pause := Flow.PLAYING

func _ready() -> void:
	# 暂停时也要收得到 Esc，渐变也要接着播。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_overlay()
	player_died.connect(_on_player_died)
	npc_rescued.connect(_on_npc_rescued)
	checkpoint_reached.connect(_write.unbind(1))
	chapter_cleared.connect(_on_chapter_cleared)
	boss_state_changed.connect(_on_boss_state_changed)

## 亮度上限：固定值。救人不再提高上限（2026-11 改），亮度只靠地图上的小星星补。
func light_max() -> float:
	return tuning.light_base

## WASD 能推到的最高速率。没有封顶，更快只能靠地图上的加速带等机关。
func input_limit() -> float:
	return minf(tuning.max_speed, tuning.stage_top(tuning.input_max_stage))

## 标题出现时调用。第一次进标题时读存档（BOOT）。
func enter_title() -> void:
	if not _booted:
		_booted = true
		Save.read()
	flow = Flow.TITLE
	chapter_index = -1
	persist = false

func can_continue() -> bool:
	return _index_of(Save.chapter) >= 0

## 所有人都救出来了：终章里科学家出现，可以走隐藏结局。
## 连击：短时间内连续打碎敌人，返回这次是第几连（1 = 单独一个）。
## 用游戏时间算，无头测试里也能稳定。
const COMBO_WINDOW := 0.9
var combo := 0
var combo_at := -100.0

func hit_combo() -> int:
	var at := Time.get_ticks_msec() / 1000.0
	if at - combo_at > COMBO_WINDOW:
		combo = 0
	combo += 1
	combo_at = at
	return combo

## 难度：0 微光级、1 长夜级、2 永夜级（docs/settings.md）
## 长夜：补给只剩敌人旁边的；救人不再回光。
## 永夜：光掉得更快（decay_mult），敌人更多（关卡加载时复制）。
func decay_mult() -> float:
	return 1.7 if Save.difficulty >= 2 else 1.0

func keeps_shards_only_near_enemies() -> bool:
	return Save.difficulty >= 1

func rescue_refills() -> bool:
	return Save.difficulty < 1

func extra_enemies() -> bool:
	return Save.difficulty >= 2

## 难度改完重新载入当前章才生效（UI 会提示）。
func apply_difficulty() -> void:
	difficulty_changed.emit(Save.difficulty)

func everyone_rescued() -> bool:
	return Save.rescued.size() >= NPC_TOTAL

func start_new() -> void:
	Save.clear()
	persist = true
	_load_chapter(0)

func continue_game() -> void:
	persist = true
	_load_chapter(maxi(_index_of(Save.chapter), 0))

## 死亡或按 R：同一章从检查点重来。
func respawn() -> void:
	get_tree().paused = false
	_pause_menu.visible = false
	if chapter_index < 0:
		flow = Flow.PLAYING
		get_tree().reload_current_scene()
		return
	flow = Flow.RESPAWN
	_load_chapter(chapter_index)

## 调试用：把所有小人记成已救（用真实 save_id，帮助点才认得）。
func debug_rescue_all() -> void:
	Save.clear()
	for chapter: Array in chapters:
		var scene := (load(String(chapter[1])) as PackedScene).instantiate()
		if scene == null:
			continue
		for npc: Npc in scene.find_children("*", "Npc", true, false):
			var rel := String(scene.get_path_to(npc))
			Save.rescued["%s/%s" % [String(chapter[0]), rel]] = npc.role
		scene.free()

## 调试用：直接跳进真结局的 boss 战（所有人已救 + 从追逐段开始）。
func debug_true_ending() -> void:
	debug_rescue_all()
	Save.chapter = &"finale"
	Save.checkpoint = ""
	flow = Flow.CHASE
	get_tree().change_scene_to_file(FINALE_SCENE)

func toggle_pause() -> void:
	if flow == Flow.PAUSED:
		flow = _flow_before_pause
		get_tree().paused = false
		_pause_menu.visible = false
		Audio.set_ducked(false)
	elif flow == Flow.PLAYING or flow == Flow.CHASE:
		_flow_before_pause = flow
		flow = Flow.PAUSED
		get_tree().paused = true
		_pause_menu.visible = true
		Audio.set_ducked(true)
		_pause_menu.call(&"focus_first")

func to_title() -> void:
	get_tree().paused = false
	_pause_menu.visible = false
	flow = Flow.LOADING
	await _fade_to(1.0)
	get_tree().change_scene_to_file(TITLE_SCENE)
	await get_tree().process_frame
	await _fade_to(0.0)

## index 是章节表里的位置；等于表长时是终章。
func _load_chapter(index: int) -> void:
	chapter_index = index
	var finale := index >= chapters.size()
	Save.chapter = FINALE_ID if finale else String(chapters[index][0])
	_write()
	if flow != Flow.RESPAWN:
		flow = Flow.LOADING
	await _fade_to(1.0)
	if finale:
		get_tree().change_scene_to_file(FINALE_SCENE)
	else:
		var chapter := (load(chapters[index][1]) as PackedScene).instantiate() as Chapter
		chapter.prepare(Chapter.Mode.NORMAL)
		get_tree().change_scene_to_node(chapter)
	await get_tree().process_frame
	flow = Flow.CHASE if finale else Flow.PLAYING
	await _fade_to(0.0)

func _on_chapter_cleared(_id: StringName) -> void:
	if chapter_index < 0 or flow != Flow.PLAYING:
		return
	flow = Flow.CLEAR
	Save.checkpoint = ""
	await get_tree().create_timer(CLEAR_TIME).timeout
	_load_chapter(chapter_index + 1)

## 噬光者退回黑暗 = 正常结局；被撞碎 = 隐藏结局。等它的演出播完再切。
func _on_boss_state_changed(state: int) -> void:
	if flow != Flow.CHASE:
		return
	if state == Boss.State.RETREAT or state == Boss.State.SHATTERED:
		flow = Flow.ENDING
		await get_tree().create_timer(Boss.FADE_TIME).timeout
		_show_ending(&"hidden" if state == Boss.State.SHATTERED else &"main")

func _show_ending(kind: StringName) -> void:
	flow = Flow.ENDING
	ending = kind
	Save.endings[kind] = true
	Save.chapter = ""
	Save.checkpoint = ""
	_write()
	await _fade_to(1.0)
	chapter_index = -1
	get_tree().change_scene_to_file(ENDING_SCENE)
	await get_tree().process_frame
	await _fade_to(0.0)

func _on_player_died(_cause: int) -> void:
	if flow == Flow.PLAYING or flow == Flow.CHASE:
		respawn()

## 邮差被救：等信的人一起被救。人在这一章就让他自己演出来，不在的只记进存档。
func _on_npc_rescued(id: String) -> void:
	# 用 get() 查：id 不在里面时直接下标访问会报错（信号可能被别的代码带着陌生 id 触发）。
	if Save.rescued.get(id, &"") == &"postman":
		for target in Save.mail.keys():
			if Save.rescued.has(target):
				continue
			var npc := _loaded_npc(target)
			if npc != null:
				npc.rescue()
			else:
				Save.rescued[target] = Save.mail[target]
				npc_rescued.emit(target)
	_write()

func _loaded_npc(id: String) -> Npc:
	for node in get_tree().get_nodes_in_group(&"npc"):
		if node.save_id == id:
			return node as Npc
	return null

## 存档里的 chapter 在章节表里的位置；终章是表长；找不到是 -1。
func _index_of(chapter_id: String) -> int:
	if chapter_id == FINALE_ID:
		return chapters.size()
	for i in chapters.size():
		if String(chapters[i][0]) == chapter_id:
			return i
	return -1

func _write() -> void:
	if persist:
		Save.write()

func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished

## 第一次按键、点击或触摸：Web 上要等用户操作过之后音频才允许播放，从这里解锁。
func _input(event: InputEvent) -> void:
	if Audio.locked and (event is InputEventKey or event is InputEventMouseButton or event is InputEventScreenTouch):
		Audio.unlock()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		return
	var playing := flow == Flow.PLAYING or flow == Flow.CHASE
	if event.is_action_pressed("reset") and playing:
		respawn()
		return
	var key := event as InputEventKey
	if not OS.is_debug_build() or key == null or not key.pressed or key.echo or not playing:
		return
	match key.physical_keycode:
		KEY_F2:
			debug_no_decay = not debug_no_decay
		KEY_F3:
			debug_panel = not debug_panel
		KEY_F4:
			# 从编辑器运行时，在检查器里改完 tuning.tres 并保存，按 F4 立刻生效。
			tuning = ResourceLoader.load(TUNING_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
		KEY_F5:
			# 清空这一局的进度，从这一章开头再玩一遍。
			var current := Save.chapter
			Save.clear()
			Save.chapter = current
			respawn()
		KEY_F6:
			# 一键进真结局 boss 战：所有职业都算救过，直接从追逐段开跑。
			debug_true_ending()
		_:
			return
	debug_changed.emit()

## 渐变用的黑幕和暂停菜单都挂在这里，换场景时不会被删掉。
func _setup_overlay() -> void:
	# 运行时再加载：菜单脚本要用 Game，预加载会循环引用。
	_pause_menu = (load(PAUSE_SCENE) as PackedScene).instantiate() as CanvasLayer
	_pause_menu.visible = false
	add_child(_pause_menu)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)

func _setup_input() -> void:
	for action in _ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in _ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
	for action in _MOUSE_ACTIONS:
		var ev := InputEventMouseButton.new()
		ev.button_index = _MOUSE_ACTIONS[action]
		InputMap.action_add_event(action, ev)
