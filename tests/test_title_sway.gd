extends Node
## 标题页的鼠标视差：鼠标偏到哪边，画面就往反方向挪；移回中心或移出窗口就慢慢回中。
## 没人动鼠标时必须完全静止——headless 截图和别的测试都靠这一点，别让画面自己漂。
##   godot --headless --path . --fixed-fps 60 res://tests/test_title_sway.tscn

const PATH := "user://test_title_sway_save.json"

var _failures := 0

func _ready() -> void:
	Save.path = PATH
	Save.clear()
	var title := (load("res://scenes/ui/title.tscn") as PackedScene).instantiate() as Title
	# 测试节点自己是正在建的场景，直接 add_child 会撞上"正在装配子节点"，延到下一帧再挂。
	get_tree().root.add_child.call_deferred(title)
	await _frames(2)
	await _frames(20)
	_check("没人动鼠标：不晃", title.sway().length() < 0.001)

	await _mouse_to(title, Vector2(0.98, 0.5), 40)
	_check("鼠标在右边：往左挪", title.sway().x > 0.5, "%.2f" % title.sway().x)
	_check("只有横向：竖直方向几乎不偏", absf(title.sway().y) < 0.2, "%.2f" % title.sway().y)

	await _mouse_to(title, Vector2(0.5, 0.02), 40)
	_check("鼠标在上边：往下挪", title.sway().y < -0.5, "%.2f" % title.sway().y)
	_check("换方向以后横向回中", absf(title.sway().x) < 0.2, "%.2f" % title.sway().x)

	await _mouse_to(title, Vector2(0.5, 0.5), 60)
	_check("鼠标回到中心：回中", title.sway().length() < 0.05, "%.3f" % title.sway().length())

	# 先推到右边，再移出窗口：不该一直歪着。
	await _mouse_to(title, Vector2(0.98, 0.5), 40)
	_check("又推到右边", title.sway().x > 0.5, "%.2f" % title.sway().x)
	await _mouse_to(title, Vector2(1.2, 0.5), 60)
	_check("鼠标移出窗口：回中", title.sway().length() < 0.05, "%.3f" % title.sway().length())

	# 快速划过：冲量把画面带过头一点，晃完还是要停在鼠标位置上。
	var peak := await _swipe(title, Vector2(0.5, 0.5), Vector2(0.95, 0.5), 10)
	_check("快速划过：会过冲（超过鼠标位置对应的偏移）", peak > 1.05, "%.2f" % peak)
	await _frames(120)
	_check("晃完停在鼠标位置上", absf(title.sway().x - 0.9) < 0.06, "%.2f" % title.sway().x)

	title.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("RESULT %s，失败 %d 项" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## 把鼠标挪到 at（0..1 的屏幕比例，可以超出）上，等 frames 帧让弹簧收过去。
func _mouse_to(title: Title, at: Vector2, frames: int) -> void:
	_push_motion(title, at)
	await _frames(frames)

## 用 frames 帧从 a 划到 b，返回这一路上 sway 的最大幅度。
func _swipe(title: Title, a: Vector2, b: Vector2, frames: int) -> float:
	var peak := 0.0
	for i in frames + 1:
		_push_motion(title, a.lerp(b, float(i) / float(frames)))
		await get_tree().process_frame
		peak = maxf(peak, title.sway().length())
	for i in 20:
		await get_tree().process_frame
		peak = maxf(peak, title.sway().length())
	return peak

func _push_motion(title: Title, at: Vector2) -> void:
	# push_input 收的是窗口坐标，标题铺的是画布坐标（stretch 会缩放）；用视口的最终变换换算。
	var ev := InputEventMouseMotion.new()
	ev.position = title.get_viewport().get_final_transform() * (at * title.size)
	get_tree().root.push_input(ev)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_failures += 1
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", name, detail])
