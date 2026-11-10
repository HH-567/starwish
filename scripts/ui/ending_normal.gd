class_name EndingNormal
extends Control
## 正常结局动画（跑到逃离点之后播放，替代原来的"长夜暂退"结局页）。按 Esc（或点右下角的图标）回标题。
##
## 时间线（秒，第一遍从 0 开始；之后只循环最后一段）：
##   0.0–1.2  城市全景，小星在城市中心偏下出现：自转、短拖尾、粒子
##   1.2–3.0  小星沿三次贝塞尔曲线向左上加速飞出城市：转得越来越快、拖尾越来越长，城市轻震；
##            噬光者以一对红眼在城里显出预兆
##   3.0–4.0  小星减速到达左上角锚点（屏幕 8%, 12%，夹在安全边距里），之后真实位置锁死
##   4.0–7.6  噬光者从底部正中长出来（easeInOut），城市由近到远一栋栋变暗：灯先闪、再灭、
##            光点被吸进噬光者；7.4 前后是高潮：震动、暗角、冲击波（不全黑，小星和拖尾一直看得见）
##   7.6–8.4  噬光者缩回去、完全消失
##   8.4–10.0 循环段：无光的城市 + 小星原地"伪飞行"（自转、往后飘的拖尾和流光），之后一直循环这 1.6 秒
## 循环段里的每样东西都是时间的周期函数（周期整除 1.6 秒），所以首尾无缝。
##
## 像素风：整段画在半分辨率的 SubViewport 里，用 Nearest 放大 2 倍；贴图用游戏里的原图
## （小星 star_body.png、噬光者 devourer.png），城市剪影没有现成素材，用标题页的色板程序画（见 EndingWorld 的 TODO）。

const PIXEL := 2
const LOOP_START := 8.4
const LOOP_LEN := 1.6
## 小星最后停的位置（屏幕比例）和离屏幕边至少多远（半分辨率像素，= 24 屏幕像素）。
const ANCHOR := Vector2(0.08, 0.12)
const SAFE := 12.0
## 小星精灵的半宽（star_body.png 32×32，半分辨率里按 1 倍画）。
const STAR_HALF := 16.0
const FLY_FROM := 1.2
const ACCEL_END := 3.0
const ARRIVE := 4.0
## 加速段走完曲线的多少（剩下的在减速段走完）。
const U_ACCEL := 0.7
## 循环段的转速：1.6 秒正好转 3 圈，首尾角度一致。
const SPIN_LOOP := TAU * 3.0 / LOOP_LEN
const SPIN_START := 2.0
const TRAIL_POINTS := 24
const TRAIL_STEP := 0.025
const ART_STAR := "res://assets/art/players/star_body.png"
const STAR_COLOR := Color("ffd75a")
## 拖尾颜色沿用游戏里的速度档颜色（data/tuning.tres 的 trail_colors）。
const PSEUDO_STAGE := 4
## 第一遍里各个时刻的音效。
const CUES := [
	[0.15, &"shard", 1.0], [0.55, &"shard", 1.26], [1.2, &"gear", 1.0], [2.0, &"accel", 1.0],
	[2.8, &"gear", 1.26], [4.0, &"boss", 1.0], [4.7, &"scatter", 0.7], [5.4, &"scatter", 0.62],
	[6.1, &"scatter", 0.55], [6.8, &"scatter", 0.5], [7.4, &"smash", 0.8], [7.42, &"meteor", 0.9],
	[7.75, &"warp", 0.6],
]

## 从进入这个画面起过了多少秒（不循环）。测试和截图可以直接设它。
var clock := 0.0
var _left := false
var _sub: SubViewport
var _cam: Camera2D
var _world: EndingWorld
var _star_layer: CanvasLayer
var _star: Sprite2D
var _trail: Line2D
var _fx: Node2D
var _vignette: TextureRect
var _skip: IconButton

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Audio.set_ducked(false)
	Audio.play_bgm(&"ending_normal")
	var box := SubViewportContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.stretch_shrink = PIXEL
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_sub = SubViewport.new()
	_sub.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_sub.snap_2d_transforms_to_pixel = true
	_sub.snap_2d_vertices_to_pixel = true
	box.add_child(_sub)
	_world = EndingWorld.new()
	_world.ending = self
	_sub.add_child(_world)
	_cam = Camera2D.new()
	_sub.add_child(_cam)
	_cam.make_current()
	# 小星在屏幕空间（CanvasLayer）：城市震动时它不跟着抖，锚点直接按 SubViewport 的尺寸算。
	_star_layer = CanvasLayer.new()
	_star_layer.layer = 1
	_sub.add_child(_star_layer)
	_vignette = TextureRect.new()
	_vignette.texture = _vignette_texture()
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_star_layer.add_child(_vignette)
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	_star_layer.add_child(_fx)
	_trail = Line2D.new()
	_trail.antialiased = false
	var width := Curve.new()
	width.add_point(Vector2(0.0, 1.0))
	width.add_point(Vector2(1.0, 0.0))
	_trail.width_curve = width
	_trail.width = 7.0
	_trail.gradient = Gradient.new()
	_star_layer.add_child(_trail)
	_star = Sprite2D.new()
	_star.texture = load(ART_STAR) as Texture2D
	_star_layer.add_child(_star)
	# 右下角一个暗暗的"回到标题"图标：触屏没有 Esc，点它也能走；和小星在对角，不挡它。
	_skip = IconButton.make(IconButton.Kind.HOME, "回到标题")
	_skip.dim = true
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.position = Vector2(-IconButton.SIZE - 24.0, -IconButton.SIZE - 24.0)
	_skip.pressed.connect(_leave)
	add_child(_skip)
	_apply(0.0)

## 第一遍按真实时间走；过了循环段的末尾就只在最后 1.6 秒里循环。
static func anim_time(c: float) -> float:
	if c < LOOP_START + LOOP_LEN:
		return c
	return LOOP_START + fposmod(c - LOOP_START, LOOP_LEN)

func _process(delta: float) -> void:
	var before := clock
	clock += delta
	if before < LOOP_START + LOOP_LEN:
		for cue: Array in CUES:
			if before < cue[0] and clock >= cue[0]:
				Audio.play(cue[1], cue[2])
	_apply(anim_time(clock))
	# 伪飞行的风声：起飞后一直有，循环段里不停。
	var t := anim_time(clock)
	if t >= FLY_FROM:
		Audio.hold(&"ending_wind", &"wind", 0.35 + 0.35 * smoothstep(FLY_FROM, ACCEL_END, t), 1.1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_leave()

func _leave() -> void:
	if _left:
		return
	_left = true
	Game.to_title()

## 半分辨率画布的尺寸。
func canvas_size() -> Vector2:
	return Vector2(_sub.size) if _sub != null and _sub.size.x > 0 else size / PIXEL

## 小星最后停的位置：屏幕 8%、12%，但至少离边 SAFE + 半个星体，任何分辨率都完整可见。
func anchor() -> Vector2:
	var s := canvas_size()
	return Vector2(maxf(s.x * ANCHOR.x, SAFE + STAR_HALF), maxf(s.y * ANCHOR.y, SAFE + STAR_HALF))

## 世界坐标 → 小星那一层（屏幕）坐标：镜头的画布变换，不算震动（震动只给城市）。
func world_to_screen(p: Vector2) -> Vector2:
	var xf := Transform2D(0.0, canvas_size() * 0.5 - _cam.position)
	return xf * p

func _bezier(u: float) -> Vector2:
	var s := canvas_size()
	var p0 := world_to_screen(_world.spawn_point())
	var p3 := anchor()
	var p1 := p0 + Vector2(0.04 * s.x, -0.36 * s.y)
	var p2 := p3 + Vector2(0.28 * s.x, 0.04 * s.y)
	var v := 1.0 - u
	return p0 * v * v * v + p1 * 3.0 * v * v * u + p2 * 3.0 * v * u * u + p3 * u * u * u

## 曲线参数：加速段 u = 0.7·s²；减速段用 Hermite 曲线接上加速段末尾的速度，到 4.0 秒停在 1。
static func flight_u(t: float) -> float:
	if t <= FLY_FROM:
		return 0.0
	if t <= ACCEL_END:
		var s := (t - FLY_FROM) / (ACCEL_END - FLY_FROM)
		return U_ACCEL * s * s
	if t >= ARRIVE:
		return 1.0
	var d := ARRIVE - ACCEL_END
	var s2 := (t - ACCEL_END) / d
	var m0 := U_ACCEL * 2.0 / (ACCEL_END - FLY_FROM) * d
	var s3 := s2 * s2 * s2
	var ss := s2 * s2
	return (2.0 * s3 - 3.0 * ss + 1.0) * U_ACCEL + (s3 - 2.0 * ss + s2) * m0 + (-2.0 * s3 + 3.0 * ss)

## 小星在第 t 秒的位置（屏幕坐标）。出场时在原地轻轻绕个小圈，1.2 秒起沿曲线飞，4 秒后锁死在锚点。
func star_pos(t: float) -> Vector2:
	var p := _bezier(flight_u(t))
	if t < FLY_FROM + 0.3:
		var hover := Vector2(cos(t * 5.2), sin(t * 5.2) * 0.6) * 3.0
		p += hover * (1.0 - smoothstep(FLY_FROM - 0.2, FLY_FROM + 0.3, t))
	return p

## 自转角度：出场 2 rad/s，飞行中线性加速到循环段的转速，之后匀速（1.6 秒 3 圈）。
static func spin(t: float) -> float:
	var ramp := ARRIVE - FLY_FROM
	if t <= FLY_FROM:
		return SPIN_START * t
	var a := SPIN_START * FLY_FROM
	if t <= ARRIVE:
		var x := t - FLY_FROM
		return a + SPIN_START * x + (SPIN_LOOP - SPIN_START) * x * x / (2.0 * ramp)
	var at_arrive := a + SPIN_START * ramp + (SPIN_LOOP - SPIN_START) * ramp * 0.5
	return at_arrive + SPIN_LOOP * (t - ARRIVE)

## 循环段的相位 0..1（4 秒起就按它走，8.4 秒起整段循环）。
static func phase(t: float) -> float:
	return fposmod((t - LOOP_START) / LOOP_LEN, 1.0)

## 伪飞行时"身后"的方向：曲线最后一段切线的反方向（往右下）。
func back_dir() -> Vector2:
	return (_bezier(0.97) - anchor()).normalized()

func trail_points(t: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var w := smoothstep(ARRIVE, ARRIVE + 0.6, t)
	var back := back_dir()
	var side := back.orthogonal()
	var ph := phase(t)
	var a := anchor()
	for k in TRAIL_POINTS:
		var hist := star_pos(maxf(t - k * TRAIL_STEP, 0.0))
		var f := float(k) / (TRAIL_POINTS - 1)
		# 伪飞行的拖尾：往身后拉出 120 px，带一点每 0.8 秒一次的摆动（1.6 秒两次，首尾接得上）
		var pseudo := a + back * (k * 5.0) + side * 4.0 * sin(TAU * (2.0 * ph) - k * 0.35) * f
		pts.append(hist.lerp(pseudo, w))
	return pts

## 拖尾颜色：出场是阶段 1 的白，飞起来按阶段颜色一路变到阶段 4 的蓝。
static func trail_color(t: float) -> Color:
	var colors := Game.tuning.trail_colors
	var k := smoothstep(FLY_FROM, ACCEL_END, t) * float(PSEUDO_STAGE - 1)
	var i := mini(int(k), PSEUDO_STAGE - 2)
	return colors[i].lerp(colors[i + 1], k - i)

## 暗角（0..1）：吞城时越来越重，7.4 秒冲一下，之后停在一个固定值（循环段里不变）。
static func vignette(t: float) -> float:
	var base := 0.4 * smoothstep(4.0, 7.2, t)
	var pulse := 0.25 * maxf(0.0, 1.0 - absf(t - 7.45) / 0.35)
	return base + pulse

func _apply(t: float) -> void:
	_world.time = t
	_world.queue_redraw()
	_world.sync_boss()
	_cam.position = canvas_size() * 0.5
	_cam.offset = _world.shake(t)
	var appear := 1.0 if t > 0.55 else ease(clampf((t - 0.15) / 0.4, 0.0, 1.0), 0.4)
	_star.position = star_pos(t)
	_star.rotation = spin(t)
	_star.scale = Vector2.ONE * appear
	_star.visible = appear > 0.01
	_trail.points = trail_points(t) if appear > 0.01 else PackedVector2Array()
	var c := trail_color(t)
	_trail.gradient.set_color(0, Color(c, 0.9 * appear))
	_trail.gradient.set_color(1, Color(c, 0.0))
	_vignette.size = canvas_size()
	_vignette.modulate.a = vignette(t)
	_fx.queue_redraw()

## 小星身边的光和粒子：出场的一圈星屑、飞行时沿路掉的火星、伪飞行时往身后飘的火星和流光。
func _draw_fx() -> void:
	var t := anim_time(clock)
	var p := star_pos(t)
	var appear := 1.0 if t > 0.55 else clampf((t - 0.15) / 0.4, 0.0, 1.0)
	if appear <= 0.0:
		return
	var ph := phase(t)
	# 星体光晕：像素圆一层层叠，呼吸周期 0.8 秒（循环段两次）
	var breathe := 0.5 + 0.5 * sin(TAU * 2.0 * ph)
	for k in 4:
		_fx.draw_circle(p, (26.0 - k * 6.0) * appear, Color(STAR_COLOR, (0.04 + 0.03 * k + 0.02 * breathe) * appear))
	# 出场：一圈往外散的星屑
	if t < 1.0:
		var b := clampf((t - 0.15) / 0.8, 0.0, 1.0)
		for i in 10:
			var dir := Vector2.from_angle(TAU * i / 10.0 + 0.3)
			_spark(p + dir * (6.0 + 30.0 * ease(b, 0.3)), Color(1.0, 0.92, 0.6, 1.0 - b), i % 3 == 0)
	var back := back_dir()
	var side := back.orthogonal()
	if t < ARRIVE:
		# 飞行中沿路掉火星：0.66 秒后淡完
		for i in 12:
			var f := fposmod(t * 1.5 + float(i) / 12.0, 1.0)
			var born := t - f * 0.66
			if born < 0.2:
				continue
			var drift := Vector2(sin(i * 7.31), cos(i * 3.17)) * 10.0 * f
			_spark(star_pos(born) + drift, Color(trail_color(born), 1.0 - f), i % 4 == 0)
	if t >= ARRIVE - 0.2:
		var on := smoothstep(ARRIVE - 0.2, ARRIVE + 0.6, t)
		var a := anchor()
		# 伪飞行：火星从身后往外飘（每颗 1.6 秒走两趟）
		for i in 12:
			var f := fposmod(2.0 * ph + float(i) / 12.0, 1.0)
			var at := a + back * (8.0 + f * 70.0) + side * (sin(i * 12.9898) * 10.0) * (0.3 + f)
			_spark(at, Color(trail_color(t), (1.0 - f) * on), i % 3 == 0)
		# 流光：几道细线从左上往右下掠过小星，看起来是它在往前冲
		for i in 8:
			var f := fposmod(3.0 * ph + float(i) / 8.0, 1.0)
			var lane := side * (float(i) - 3.5) * 9.0
			var head := a + lane + back * (-40.0 + f * 150.0)
			var alpha := on * 0.5 * (1.0 - absf(f - 0.5) * 2.0)
			_fx.draw_line(head, head + back * (10.0 + 8.0 * float(i % 3)), Color(0.85, 0.9, 1.0, alpha), 1.0)

## 一颗像素火星：单像素，或者加号形的小十字。
func _spark(at: Vector2, c: Color, cross: bool) -> void:
	if c.a <= 0.01:
		return
	var p := at.floor()
	_fx.draw_rect(Rect2(p, Vector2.ONE), c)
	if cross:
		var dim := Color(c, c.a * 0.5)
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_fx.draw_rect(Rect2(p + d, Vector2.ONE), dim)

func _vignette_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.01, 0.0, 0.03, 0.25), Color(0.01, 0.0, 0.03, 0.95)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 0.5)
	tex.width = 160
	tex.height = 90
	return tex
