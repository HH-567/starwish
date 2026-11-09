@tool
class_name HelpPoint
extends Area2D
## 帮助点：只在回程赛道和终章结尾里（docs/state-machines.md 第 18 节）。对应的人已救，他就站在路边，
## 小星经过时按他的职业帮一次，发 help_triggered；没救就不出现，子节点（路灯、花、光门、隧道）也一起没了。
## 触发范围是穿过他的一根竖条：赛道是横的，小星从哪一行经过都算。

const BAND_WIDTH := 48.0
const LAMP := 90.0
## 守夜人的路灯从近到远一盏盏亮，每秒传多远。
const CASCADE_SPEED := 1600.0
const FLASH_TIME := 0.6
## 小人特写：推进去多久、拉回来多久（秒）。
const CINE_IN := 1.05
## 特写推到的缩放（1.9 = 很近）。
const CINE_ZOOM := 1.9
const CINE_OUT := 0.55

## 指向 Level 里的那个人。Chapter.prepare(FINALE) 删掉 Level 之前调 resolve()，记下他的 save_id 和职业。
@export var npc: NodePath
@export var npc_id := ""
@export_enum("none", "watchman", "gardener", "doctor", "painter", "guide", "miner", "locksmith", "postman", "musician", "listener", "clockmaker", "scientist") var role := "none":
	set(value):
		role = value
		queue_redraw()
## 所有人都已救才出现，不看 npc_id（终章结尾的科学家）。
@export var everyone := false
## 竖条从帮助点往上、往下各伸多远。
@export var reach := 600.0:
	set(value):
		reach = value
		queue_redraw()

var triggered := false
var _t := 0.0
var _flash := 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not is_present():
		queue_free()
		return
	add_to_group(&"help_point")
	material = Lighting.unshaded()
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	Shapes.add_rect(self, Vector2(BAND_WIDTH, reach * 2.0))
	add_child(Lighting.point_light(LAMP, Npc.GLOW, 0.7))
	body_entered.connect(_on_body_entered)

## 记下 npc 指向的那个人的 save_id 和职业。
func resolve() -> void:
	var target := get_node_or_null(npc) as Npc
	if target != null:
		npc_id = Save.id_of(target)
		role = target.role

## 对应的人已救；everyone 时要所有人都已救。
func is_present() -> bool:
	return Game.everyone_rescued() if everyone else Save.rescued.has(npc_id)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player == null or triggered:
		return
	triggered = true
	_flash = FLASH_TIME
	_help(player)
	Debris.spawn(get_parent(), global_position, Npc.GLOW, 14, 220.0, 4.0, true)
	Game.help_triggered.emit(StringName(role))
	_cinematic(player)


## 追逐战里的小人特写：镜头切到小人 → 特效（光环 + 打向噬光者的光柱）→ 回到小星。
## 特写期间时间放慢（镜头 sweep 自己会做），游戏逻辑照常跑，不会漏判定。
func _cinematic(player: Player) -> void:
	if Game.flow != Game.Flow.CHASE:
		return
	var boss := get_tree().get_first_node_in_group(&"boss") as Boss
	# 特写要同时框住"帮忙的小人 + 被影响的噬光者"，不然只看得到特效、看不到 boss 的反应。
	var boss_at := global_position
	if boss != null:
		boss_at = boss.global_position
	var mid := (global_position + boss_at) * 0.5
	var span := global_position.distance_to(boss_at)
	# 距离越远拉得越开（视口 1280 宽，留 15% 边）
	var zoom_to := clampf(1100.0 / maxf(span, 260.0), 0.5, 2.0)
	# 高速时把特效放大，特写里才看得清
	var speed_mul := 1.0 + clampf(player.velocity.length() / 700.0, 0.0, 1.2)
	HelpFx.spawn(get_parent(), global_position, boss_at, Npc.GLOW, speed_mul)
	var cam := player.get_node_or_null(^"Camera") as Camera2D
	if cam == null or not cam.has_method("sweep"):
		return
	# 铺路演出可能正占着镜头：等它结束再推（最多等 120 帧，别把特写丢了）
	for i in 120:
		if not cam.has_method("is_sweeping") or not cam.call("is_sweeping"):
			break
		if not is_inside_tree():
			return
		await get_tree().process_frame
	# 推过去特写；结束时镜头自己的平滑会把视角带回小星，不用再来一次 sweep
	cam.sweep(mid, CINE_IN, zoom_to)

## 按职业帮一次。园丁、画家、矿工的帮助就是他们的子节点（花、光门、隧道），这里不用再做什么。
func _help(player: Player) -> void:
	var t := Game.tuning
	var boss := get_tree().get_first_node_in_group(&"boss") as Boss
	match role:
		"watchman":
			player.shield = true
			for child in get_children():
				if child is Lamp:
					(child as Lamp).light_up(global_position.distance_to(child.global_position) / CASCADE_SPEED)
		"doctor":
			player.add_light(player.light_max)
		"musician":
			if boss != null:
				boss.knockback(t.help_knockback)
		"clockmaker":
			if boss != null:
				boss.slow(t.help_slow_time)
		"miner":
			# 矿工的"帮忙"就是挖开这堵墙：等玩家跑到他跟前才挖，不是一进关就通
			for child in get_children():
				if child is Tunnel:
					(child as Tunnel).open()

func _draw() -> void:
	Npc.draw_figure(self, true)
	Dreams.draw(self, role, 1.0, _t)
	if _flash > 0.0:
		var k := 1.0 - _flash / FLASH_TIME
		draw_arc(Vector2.ZERO, lerpf(20.0, 90.0, k), 0.0, TAU, 40, Color(Npc.GLOW, 0.8 * (1.0 - k)), 3.0, true)
	if Engine.is_editor_hint():
		draw_rect(Rect2(-BAND_WIDTH * 0.5, -reach, BAND_WIDTH, reach * 2.0), Color(Npc.GLOW, 0.25), false, 1.0)
