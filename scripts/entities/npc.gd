@tool
class_name Npc
extends Node2D
## 小人：被照够时间就得救，梦想浮现，之后按职业帮小星（docs/state-machines.md 第 3、18 节）。
## 怎么救靠摆放：直接照、先烧影藤、先撞开裂纹墙、只有反射光照得到、隔着栅栏、两人同时照。
## 结伴的两人只在其中一人身上设 partner，由那个人算进度。
## 小人本身不发光，被照到才看得见；哭声的声波圈、进度和浮现的梦想自己发光。

enum State { CRYING, WAKING, RESCUED }

const BODY := Color("e8ecff")
const WAVE := Color("b9c8ff")
const GLOW := Color("ffd98a")
const WAVE_PERIOD := 1.6
const WAVE_MAX := 46.0
const RING_RADIUS := 17.0
## 被救后身上那盏小灯的半径。
const LAMP := 72.0
## 梦想浮现要多久，秒。
const DREAM_TIME := 0.8
## 美术图：assets/art/characters/npc_<职业>.png。没有图就退回原来的几何画法（两种都能跑）。
const ART_DIR := "res://assets/art/characters/"
## 图是 32×32 的剪影，脚底在画布中心偏下，往上挪一点和原来的小人脚底对齐。
const ART_OFFSET := Vector2(0.0, -7.0)

## 职业：决定外观、浮现的画面和帮助（docs/level-data-format.md 第 7 节）。
@export_enum("none", "watchman", "gardener", "doctor", "painter", "guide", "miner", "locksmith", "postman", "musician", "listener", "clockmaker", "scientist") var role := "none":
	set(value):
		role = value
		queue_redraw()
## 要照多久，0 = 用默认值（wake_time，结伴 pair_time）。
@export var need_time := 0.0
## 结伴对象：两人同时被照到进度才涨。只在其中一人身上设。
@export var partner: NodePath
## 藏着的人：向导被救之前不出声、不显示声波圈。照到了照样能救。
@export var secret := false
## 照不到的人：小星的光不算数，邮差被救时远程点亮。
@export var mail := false

var state := State.CRYING
var progress := 0.0
var save_id := ""

var _partner: Npc
## 结伴时带头的那个人。自己是跟随者时不算进度，显示带头人的进度。
var _leader: Npc
var _lit_frame := -10
var _t := 0.0
var _dream_t := 0.0
var _aura: Node2D
var _lamp: PointLight2D
## 有美术图时用它，没有就是 null（走 _draw 里的几何小人）。
var _art: Sprite2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"npc")
	add_to_group(&"light_receiver")
	save_id = Save.id_of(self)
	_load_art()
	_t = randf() * WAVE_PERIOD
	_aura = Node2D.new()
	_aura.material = Lighting.unshaded()
	_aura.draw.connect(_draw_aura)
	add_child(_aura)
	_lamp = Lighting.point_light(LAMP, GLOW, 0.7)
	_lamp.visible = false
	add_child(_lamp)
	_partner = get_node_or_null(partner) as Npc
	if _partner != null:
		_partner._leader = self
	if mail and not Save.rescued.has(save_id):
		if Save.has_role(&"postman"):
			# 邮差早就救了，信已经到了。
			Save.rescued[save_id] = StringName(role)
		else:
			Save.mail[save_id] = StringName(role)
	if Save.rescued.has(save_id):
		_set_state(State.RESCUED)
		_dream_t = DREAM_TIME

func receive_light(_mode: int, _delta: float) -> void:
	if not mail:
		_lit_frame = Engine.get_physics_frames()

func light_target(_from: Vector2) -> Vector2:
	return global_position

## 这一帧或上一帧被照到。小星的光在小人之后才算，所以要算上上一帧。
func is_lit() -> bool:
	return Engine.get_physics_frames() - _lit_frame <= 1

## 听得见哭声：不是藏着的人，或者向导已经被救。
func is_heard() -> bool:
	return not secret or Save.has_role(&"guide")

func need() -> float:
	if need_time > 0.0:
		return need_time
	var paired := _partner != null or _leader != null
	return Game.tuning.pair_time if paired else Game.tuning.wake_time

## 得救：照够时间时自己调用；邮差远程点亮时 Game 调用。
func rescue() -> void:
	if state == State.RESCUED:
		return
	_set_state(State.RESCUED)
	_dream_t = 0.0
	Save.rescued[save_id] = StringName(role)
	Debris.spawn(get_parent(), global_position, GLOW, 12, 180.0, 4.0, true)
	Game.npc_rescued.emit(save_id)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_dream_t += delta
	_aura.queue_redraw()
	if state == State.RESCUED or _leader != null:
		return
	var lit := is_lit() and (_partner == null or _partner.is_lit())
	if state == State.CRYING and lit:
		_set_state(State.WAKING)
	if state == State.WAKING:
		progress += delta if lit else -delta * Game.tuning.progress_decay
		if progress <= 0.0:
			_set_state(State.CRYING)
		elif progress >= need():
			rescue()
			if _partner != null:
				_partner.rescue()

func _set_state(next: State) -> void:
	state = next
	if next == State.CRYING:
		progress = 0.0
	elif next == State.RESCUED:
		progress = need()
		# 被救后自己发光，变成一个小光源。
		material = Lighting.unshaded()
		if _art != null:
			_art.material = Lighting.unshaded()
		_lamp.visible = true
	queue_redraw()

## 有美术图就用图：图跟着节点一起被光照（暗处看不见，被照亮才露出来），
## 救了之后换成自己发光。没图就什么都不做，下面的 _draw 照常画几何小人。
func _load_art() -> void:
	var key := "npc_base" if role == "none" else "npc_" + role
	var path := ART_DIR + key + ".png"
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	_art = Sprite2D.new()
	_art.texture = tex
	_art.position = ART_OFFSET
	add_child(_art)
	if state == State.RESCUED:
		_art.material = Lighting.unshaded()

func _draw() -> void:
	if _art != null:
		return
	draw_figure(self, state == State.RESCUED)

## 白色小人：头和身体。哭的时候缩成一团，被救后站直（up）。终章的帮助点也用它画。
static func draw_figure(item: CanvasItem, up: bool) -> void:
	var top := -3.0 if up else 0.0
	item.draw_colored_polygon(PackedVector2Array([Vector2(-5.5, 9.0), Vector2(5.5, 9.0), Vector2(3.5, top), Vector2(-3.5, top)]), BODY)
	item.draw_circle(Vector2(0.0, -9.0 if up else -5.0), 4.5, BODY)

func _draw_aura() -> void:
	if state == State.RESCUED:
		Dreams.draw(_aura, role, clampf(_dream_t / DREAM_TIME, 0.0, 1.0), _t)
		return
	if is_heard():
		# 哭声：一圈圈往外扩的声波，隔着墙也看得见。
		for k in 2:
			var phase := fposmod(_t / WAVE_PERIOD + k * 0.5, 1.0)
			_aura.draw_arc(Vector2.ZERO, lerpf(8.0, WAVE_MAX, phase), 0.0, TAU, 40, Color(WAVE, 0.45 * (1.0 - phase)), 1.5, true)
	var source := _leader if _leader != null else self
	if source.progress > 0.0:
		# 进度：胸口的光种慢慢长大，外面一圈进度条。
		var p := clampf(source.progress / source.need(), 0.0, 1.0)
		_aura.draw_circle(Vector2(0.0, 2.0), lerpf(1.5, 4.5, p), GLOW)
		_aura.draw_arc(Vector2.ZERO, RING_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * p, 40, Color(GLOW, 0.8), 2.0, true)
	if _partner != null and is_heard():
		_aura.draw_dashed_line(Vector2.ZERO, to_local(_partner.global_position), Color(WAVE, 0.18), 1.5, 6.0)
