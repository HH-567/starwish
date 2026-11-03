extends Node2D
## 噬光者的无头测试：沿轨迹追、吸光、盾、减速、震退、提速跟上、科学家的虫洞掉头撞碎。
##   godot --headless --path . --fixed-fps 60 res://tests/test_boss.tscn
## 空场景，没有墙。每个用例重新摆小星和噬光者，跑若干物理帧，检查结果。全部通过时退出码为 0。

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const BOSS_SCENE := preload("res://scenes/entities/boss.tscn")

var _failures := 0
var _player: Player
var _boss: Boss
## 每个物理帧开头把小星的速度设成它；null = 不管。
var _drive: Variant = null
var _states: Array[int] = []

func _ready() -> void:
	# 测试里死亡不重载场景。
	Game.player_died.disconnect(Game._on_player_died)
	Game.debug_no_decay = true
	Game.boss_state_changed.connect(func(s: int) -> void: _states.append(s))
	var finished: Variant = await _cases()
	_check("所有用例都跑完了", finished == true)
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _physics_process(_delta: float) -> void:
	# 测试根节点先于子节点处理，小星这一帧就按这个速度走。
	if _drive != null and _player != null and _player.state == Player.State.ACTIVE:
		_player.velocity = _drive

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## 小星在 at，等它出生完；噬光者在 boss_at 出现，emerge 秒后开始追。
func _begin(at: Vector2, boss_at: Vector2, emerge := 0.02) -> void:
	for node: Node in [_player, _boss]:
		if is_instance_valid(node):
			node.queue_free()
	await get_tree().physics_frame
	_drive = null
	_states.clear()
	_player = PLAYER_SCENE.instantiate() as Player
	_player.aim_from_mouse = false
	_player.position = at
	add_child(_player)
	while _player.state != Player.State.ACTIVE:
		await get_tree().physics_frame
	_boss = BOSS_SCENE.instantiate() as Boss
	add_child(_boss)
	_boss.emerge(_player, boss_at, emerge)

func _until_chase() -> void:
	while _boss.state != Boss.State.CHASE:
		await get_tree().physics_frame

func _cases() -> bool:
	var t := Game.tuning
	var contact := Boss.RADIUS + Player.RADIUS

	# 沿轨迹追：小星先往左再往上，噬光者走到拐角再拐，不抄近路。
	await _begin(Vector2.ZERO, Vector2(500, 0))
	_check("出现：先是 EMERGE", _boss.state == Boss.State.EMERGE)
	_boss.knockback(400.0)
	_check("还没开始追时震退不起作用", _boss.global_position == Vector2(500, 0))
	await _until_chase()
	_check("emerge 的时间到了开始追", _states == [Boss.State.EMERGE, Boss.State.CHASE], "%s" % [_states])
	_drive = Vector2(-600, 0)
	var x0 := _boss.global_position.x
	await _frames(18)
	_check("追的速度是 boss_speed", is_equal_approx(x0 - _boss.global_position.x, t.boss_speed * 0.3), "%.1f" % (x0 - _boss.global_position.x))
	await _frames(12)
	_drive = Vector2(0, -600)
	var corner := _player.global_position
	# 轨迹每 0.1 秒记一个点（小星走 60 px），拐角附近最多抄这么一小段近路。
	var step := 600.0 * Boss.TRAIL_STEP
	var off_line := 0.0
	var nearest := INF
	for i in 60:
		await get_tree().physics_frame
		if i == 20:
			_check("还没到拐角时，距离按轨迹算，比直线远", _boss.global_position.x > corner.x and _boss.gap() > _boss.global_position.distance_to(_player.global_position) + 50.0, "%.1f / %.1f" % [_boss.gap(), _boss.global_position.distance_to(_player.global_position)])
		if _boss.global_position.x > corner.x + step:
			off_line = maxf(off_line, absf(_boss.global_position.y))
		nearest = minf(nearest, _boss.global_position.distance_to(corner))
	_check("拐角之前一直在小星走过的直线上", off_line < 0.5, "偏了 %.2f" % off_line)
	_check("走到拐角才拐，没有抄近路", nearest < step * 0.4, "最近 %.1f" % nearest)

	# 震退：沿走过的路往回退 help_knockback。
	await _begin(Vector2.ZERO, Vector2(300, 0))
	await _until_chase()
	_drive = Vector2(-600, 0)
	await _frames(60)
	var gap := _boss.gap()
	var y_before := _boss.global_position.y
	_boss.knockback(t.help_knockback)
	_check("震退：距离多了 help_knockback", absf(_boss.gap() - gap - t.help_knockback) < 2.0, "%.1f → %.1f" % [gap, _boss.gap()])
	_check("震退沿着走过的路", is_equal_approx(_boss.global_position.y, y_before))

	# 钟表匠：速度乘 help_slow_mult。
	await _begin(Vector2.ZERO, Vector2(300, 0))
	await _until_chase()
	_drive = Vector2(-700, 0)
	_boss.slow(t.help_slow_time)
	x0 = _boss.global_position.x
	await _frames(30)
	_check("减速：速度乘 help_slow_mult", is_equal_approx(x0 - _boss.global_position.x, t.boss_speed * t.help_slow_mult * 0.5), "%.1f" % (x0 - _boss.global_position.x))

	# 落后太多：提速到 boss_catch_speed，追到 boss_gap_max 以内再降回来。
	await _begin(Vector2.ZERO, Vector2(1000, 0))
	await _until_chase()
	_drive = Vector2(-900, 0)
	x0 = _boss.global_position.x
	await _frames(12)
	_check("落后超过 boss_gap_max：提速", is_equal_approx(x0 - _boss.global_position.x, t.boss_catch_speed * 0.2), "%.1f" % (x0 - _boss.global_position.x))
	await _frames(120)
	_check("追近以后不再提速，距离停在 boss_gap_max 附近", absf(_boss.gap() - t.boss_gap_max) < 25.0, "%.1f" % _boss.gap())

	# 碰到就吸光，吸干了小星熄灭。
	await _begin(Vector2.ZERO, Vector2(30, 0))
	await _until_chase()
	_drive = Vector2.ZERO
	var full := _player.light
	await _frames(30)
	_check("接触时每秒吸走 boss_drain", absf(full - _player.light - t.boss_drain * 0.5) < 3.0, "%.1f → %.1f" % [full, _player.light])
	await _frames(30)
	_check("吸干了：小星熄灭", _player.state == Player.State.DYING and _player.death_cause == Player.Death.DRAINED)

	# 守夜人的盾：挡掉第一次接触，噬光者被弹开；之后照样吸。
	await _begin(Vector2.ZERO, Vector2(200, 0))
	_player.shield = true
	await _until_chase()
	_drive = Vector2.ZERO
	# 碰上的那一帧盾就用掉了，噬光者同一帧被弹开。
	for i in 120:
		if not _player.shield:
			break
		await get_tree().physics_frame
	_check("盾挡掉第一次接触：不扣亮度", not _player.shield and _player.light == _player.light_max)
	_check("盾把噬光者弹开", _boss.global_position.distance_to(_player.global_position) > contact, "%.1f" % _boss.global_position.distance_to(_player.global_position))
	await _frames(60)
	_check("盾用掉以后照样吸光", _player.light < _player.light_max)

	# 科学家的虫洞：以阶段 5 掉头撞上，噬光者碎了。
	await _begin(Vector2.ZERO, Vector2(600, 0))
	await _until_chase()
	_drive = Vector2(900, 0)
	_player.charge()
	var from := _boss.global_position
	await get_tree().physics_frame
	var toward := (_player.global_position - from).normalized()
	_check("小星掉头冲回来：噬光者直接扑上去", (_boss.global_position - from).normalized().dot(toward) > 0.99)
	await _frames(30)
	_check("阶段 5 撞上：噬光者碎了", _boss.state == Boss.State.SHATTERED and _states.has(Boss.State.SHATTERED))
	_check("撞上以后冲劲用掉", not _player.charged)
	await _frames(int(Boss.FADE_TIME * 60.0) + 2)
	_check("碎完消失", not _boss.visible)

	# 不到阶段 5 掉头撞上：只会被吸光，冲劲照样用掉。
	await _begin(Vector2.ZERO, Vector2(600, 0))
	await _until_chase()
	_drive = Vector2(450, 0)
	_player.charge()
	await _frames(30)
	_check("阶段 3 撞上：噬光者没碎", _boss.state == Boss.State.CHASE)
	_check("阶段 3 撞上：被吸光，冲劲用掉", _player.light < _player.light_max and not _player.charged)

	# 冲劲有时限：charge_time 之后不再冲。
	await _begin(Vector2.ZERO, Vector2(-3000, 0), 10.0)
	_player.charge()
	await _frames(int(t.charge_time * 60.0) + 2)
	_check("charge_time 之后冲劲没了", not _player.charged)

	# 跑到逃离点：退回黑暗。
	await _begin(Vector2.ZERO, Vector2(400, 0))
	await _until_chase()
	_boss.retreat()
	_check("退回黑暗", _boss.state == Boss.State.RETREAT)
	await _frames(int(Boss.FADE_TIME * 60.0) + 2)
	_check("退完消失", not _boss.visible)
	return true
