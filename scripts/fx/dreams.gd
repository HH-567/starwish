class_name Dreams
## 梦想浮现的占位画：小人被救后，头顶浮出他职业的发光图案（docs/level-data-format.md 第 7 节）。
## 用户的美术图到了就换成贴图。a = 浮现进度 0–1（淡入并放大），t 用来做轻微的呼吸。

const COLOR := Color("ffd98a")
## 图案画在小人头顶这一点附近，大约 ±36 × ±20。
const ORIGIN := Vector2(0.0, -40.0)

static func draw(item: CanvasItem, role: String, a: float, t: float) -> void:
	var c := Color(COLOR, a * (0.7 + 0.15 * sin(t * 2.0)))
	item.draw_set_transform(ORIGIN, 0.0, Vector2.ONE * lerpf(0.5, 1.0, a))
	match role:
		"watchman":
			# 身后一排路灯。
			for x in [-36.0, -12.0, 12.0, 36.0]:
				item.draw_line(Vector2(x, 18), Vector2(x, -4), c, 2.0)
				item.draw_circle(Vector2(x, -8), 4.0, c)
		"gardener":
			# 一片花。
			for i in 5:
				var p := Vector2(-30.0 + i * 15.0, 2.0 if i % 2 == 0 else -6.0)
				item.draw_line(Vector2(p.x, 18), p, c, 1.5)
				for k in 4:
					item.draw_circle(p + Vector2.from_angle(TAU * k / 4.0) * 3.5, 2.5, c)
		"doctor":
			# 药箱。
			item.draw_rect(Rect2(-14, -8, 28, 20), c, false, 2.0)
			item.draw_line(Vector2(0, -3), Vector2(0, 9), c, 2.5)
			item.draw_line(Vector2(-6, 3), Vector2(6, 3), c, 2.5)
		"painter":
			# 一整面壁画：太阳和山。
			item.draw_rect(Rect2(-30, -16, 60, 32), c, false, 2.0)
			item.draw_circle(Vector2(-14, -5), 5.0, c)
			item.draw_polyline(PackedVector2Array([Vector2(-26, 12), Vector2(-10, 0), Vector2(2, 8), Vector2(14, -6), Vector2(26, 12)]), c, 2.0)
		"guide":
			# 举起的灯和光线。
			item.draw_line(Vector2(0, 18), Vector2(0, -6), c, 2.0)
			item.draw_rect(Rect2(-5, -16, 10, 10), c)
			for k in 5:
				var d := Vector2.from_angle(-PI + PI * (k + 0.5) / 5.0)
				item.draw_line(Vector2(0, -11) + d * 10.0, Vector2(0, -11) + d * 18.0, c, 1.5)
		"miner":
			# 隧道口和镐。
			item.draw_arc(Vector2(-6, 16), 18.0, PI, TAU, 24, c, 2.5)
			item.draw_line(Vector2(-28, 16), Vector2(16, 16), c, 2.0)
			item.draw_line(Vector2(18, 12), Vector2(30, -8), c, 2.0)
			item.draw_arc(Vector2(30, -8), 8.0, PI * 0.6, PI * 1.6, 12, c, 2.0)
		"locksmith":
			# 打开的门和钥匙。
			item.draw_rect(Rect2(-12, -16, 22, 32), c, false, 2.0)
			item.draw_polyline(PackedVector2Array([Vector2(-12, -16), Vector2(-24, -11), Vector2(-24, 11), Vector2(-12, 16)]), c, 2.0)
			item.draw_arc(Vector2(20, -4), 4.0, 0.0, TAU, 12, c, 2.0)
			item.draw_line(Vector2(24, -4), Vector2(34, -4), c, 2.0)
			item.draw_line(Vector2(31, -4), Vector2(31, 1), c, 2.0)
		"postman":
			# 信封，往前飞。
			item.draw_rect(Rect2(-12, -9, 26, 18), c, false, 2.0)
			item.draw_polyline(PackedVector2Array([Vector2(-12, -9), Vector2(1, 2), Vector2(14, -9)]), c, 2.0)
			for y in [-5.0, 0.0, 5.0]:
				item.draw_line(Vector2(-30, y), Vector2(-18, y), Color(c, c.a * 0.6), 1.5)
		"musician":
			# 音符和一圈圈声波。
			item.draw_circle(Vector2(-18, 8), 3.5, c)
			item.draw_line(Vector2(-15, 8), Vector2(-15, -10), c, 2.0)
			for r in [8.0, 14.0, 20.0]:
				item.draw_arc(Vector2(-4, 0), r, -0.8, 0.8, 12, c, 2.0)
		"listener":
			# 两个音符。
			for x in [-10.0, 10.0]:
				item.draw_circle(Vector2(x, 8), 3.5, c)
				item.draw_line(Vector2(x + 3, 8), Vector2(x + 3, -8), c, 2.0)
			item.draw_line(Vector2(-7, -8), Vector2(13, -10), c, 2.0)
		"clockmaker":
			# 转动的齿轮和指针。
			item.draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 24, c, 2.0)
			for k in 8:
				var d := Vector2.from_angle(t * 0.8 + TAU * k / 8.0)
				item.draw_line(d * 12.0, d * 17.0, c, 3.0)
			item.draw_line(Vector2.ZERO, Vector2(0, -8), c, 2.0)
			item.draw_line(Vector2.ZERO, Vector2(6, 2), c, 2.0)
		"scientist":
			# 原子：三条椭圆轨道。
			for k in 3:
				var pts := PackedVector2Array()
				for i in 25:
					var u := TAU * i / 24.0
					pts.append(Vector2(cos(u) * 20.0, sin(u) * 7.0).rotated(PI * k / 3.0))
				item.draw_polyline(pts, c, 1.5)
			item.draw_circle(Vector2.ZERO, 3.5, c)
		_:
			item.draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 24, c, 2.0)
	item.draw_set_transform(Vector2.ZERO)
