extends Node
## 正常结局动画：时间线的几个硬要求（锚点、噬光者消失、城市全灭、循环无缝）和 Esc 回标题。
##   godot --headless --path . --fixed-fps 60 res://tests/test_ending_normal.tscn

const SCENE := "res://scenes/ui/ending_normal.tscn"

var _failures := 0

func _ready() -> void:
	var finished: Variant = await _run()
	_check("全部步骤都跑完了", finished == true)
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])

func _run() -> bool:
	_check("正常结局走动画，隐藏结局还是结局页",
		Game.ending_scene(&"main") == Game.ENDING_NORMAL_SCENE and Game.ending_scene(&"hidden") == Game.ENDING_SCENE)
	# 只循环最后一段：第一遍照常走，之后每 1.6 秒回到 8.4。
	var a := EndingNormal.anim_time(8.9)
	_check("第一遍按真实时间走", is_equal_approx(EndingNormal.anim_time(3.3), 3.3) and is_equal_approx(a, 8.9))
	_check("之后只循环最后一段", is_equal_approx(EndingNormal.anim_time(8.9 + 1.6 * 5.0), a), "%.3f" % EndingNormal.anim_time(8.9 + 8.0))
	_check("自转：循环段首尾角度差整圈", is_zero_approx(fposmod(EndingNormal.spin(10.0) - EndingNormal.spin(8.4), TAU)) or is_equal_approx(fposmod(EndingNormal.spin(10.0) - EndingNormal.spin(8.4), TAU), TAU))
	_check("噬光者：吞城时在，8.4 秒起完全消失", EndingWorld.boss_size(6.0) > 0.5 and EndingWorld.boss_size(8.4) == 0.0 and EndingWorld.boss_size(9.5) == 0.0)
	_check("噬光者长大是 easeInOut（两头慢中间快）",
		EndingWorld.boss_size(4.32) < 0.05 and EndingWorld.boss_size(5.6) > 0.45 and EndingWorld.boss_size(5.6) < 0.55)

	var ending := (load(SCENE) as PackedScene).instantiate() as EndingNormal
	add_child(ending)
	await get_tree().process_frame
	await get_tree().process_frame
	var canvas := ending.canvas_size()
	_check("半分辨率画布跟着窗口走", canvas.x > 100.0 and is_equal_approx(canvas.x * EndingNormal.PIXEL, ending.size.x), "%s / %s" % [canvas, ending.size])
	var at := ending.anchor()
	var expect := Vector2(canvas.x * 0.08, canvas.y * 0.12)
	_check("锚点在屏幕 8%、12%", at.distance_to(expect) < 1.0 or at.x >= EndingNormal.SAFE + EndingNormal.STAR_HALF, "%s" % at)
	_check("小星在锚点完整可见（离边 ≥ 安全边距）",
		at.x - EndingNormal.STAR_HALF >= EndingNormal.SAFE - 0.01 and at.y - EndingNormal.STAR_HALF >= EndingNormal.SAFE - 0.01)
	_check("出场在城市中心偏下", ending.star_pos(0.5).distance_to(Vector2(canvas.x * 0.5, canvas.y * 0.66)) < 6.0, "%s" % ending.star_pos(0.5))
	_check("4 秒起位置锁死在锚点", ending.star_pos(4.0).distance_to(at) < 0.5 and ending.star_pos(6.3).distance_to(at) < 0.5 and ending.star_pos(9.9).distance_to(at) < 0.5)
	var p2 := ending.star_pos(2.0)
	_check("飞行途中往左上走", p2.x < canvas.x * 0.5 + 30.0 and p2.y < ending.star_pos(0.5).y - 20.0, "%s" % p2)
	var world := ending.find_children("*", "EndingWorld", true, false)[0] as EndingWorld
	_check("开头城里亮着灯", world._lit_fraction(1.0) > 0.99)
	_check("吞城途中一栋栋熄灭（不是一下全灭）", world._lit_fraction(5.8) > 0.2 and world._lit_fraction(5.8) < 0.8, "%.2f" % world._lit_fraction(5.8))
	_check("循环段里一盏灯都不剩", world._lit_fraction(8.4) == 0.0)
	_check("循环段里没有震动", world.shake(8.4) == Vector2.ZERO and world.shake(9.7) == Vector2.ZERO)
	_check("暗角：高潮不全黑，循环段恒定", EndingNormal.vignette(7.45) < 0.8 and is_equal_approx(EndingNormal.vignette(8.4), EndingNormal.vignette(9.9)))
	# 按 Esc 回标题
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	# Game.to_title 会换场景（连这个测试节点一起删掉），这里只看它已经开始回标题：只走一次、流程切到 LOADING。
	_check("按 Esc 回标题", ending._left and Game.flow == Game.Flow.LOADING, "flow=%d" % Game.flow)
	return true
