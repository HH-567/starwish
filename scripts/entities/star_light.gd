class_name StarLight
extends Node2D
## 小星的光（docs/state-machines.md 2.4）：每个物理帧找出被照到的 light_receiver，调用它的 receive_light()；
## 再摆好画面上的光源，画出表示亮度的光环。挂在 Player 下面。
## light_receiver 组里的节点要有 light_target(from) -> Vector2（拿哪个点判断距离、角度和视线）
## 和 receive_light(mode, delta)。

const COLOR := Color(1.0, 0.86, 0.55)
const FOCUS_ENERGY := 1.3
## 反射光从击中点往外挪一点，射线和光源都不碰到玻璃自己。
const REFLECT_NUDGE := 2.0

## 本帧聚光的中心射线是否打到玻璃；反射光的起点、方向、剩余距离。判定和画面共用。
var reflecting := false
var reflect_from := Vector2.ZERO
var reflect_dir := Vector2.RIGHT
var reflect_range := 0.0

var _scatter: PointLight2D
var _focus: PointLight2D
var _reflect: PointLight2D

@onready var _player := get_parent() as Player

func _ready() -> void:
	material = Lighting.unshaded()
	_scatter = Lighting.point_light(1.0, COLOR, 1.0, true)
	add_child(_scatter)
	_focus = _cone_light()
	add_child(_focus)
	_reflect = _cone_light()
	_reflect.top_level = true
	add_child(_reflect)

func _physics_process(delta: float) -> void:
	reflecting = false
	if _player.state == Player.State.ACTIVE:
		_shine(delta)
	_update_lights()
	queue_redraw()

func _shine(delta: float) -> void:
	var t := Game.tuning
	var space := get_world_2d().direct_space_state
	var from := global_position
	var focus := _player.light_mode == Player.LightMode.FOCUS
	var radius := t.scatter_radius(_player.light)
	var reach := radius * t.focus_range_mult
	var half := deg_to_rad(t.focus_half_angle)
	var aim := _player.aim
	if focus:
		var hit := _ray(space, from, from + aim * reach)
		if not hit.is_empty() and hit.collider is Mirror:
			reflecting = true
			reflect_dir = aim.bounce(hit.normal)
			reflect_from = hit.position + reflect_dir * REFLECT_NUDGE
			reflect_range = reach - from.distance_to(hit.position)
	for node in get_tree().get_nodes_in_group(&"light_receiver"):
		var lit := false
		if focus:
			lit = _in_cone(space, node, from, aim, reach, half)
			if not lit and reflecting:
				lit = _in_cone(space, node, reflect_from, reflect_dir, reflect_range, half)
		else:
			var p: Vector2 = node.light_target(from)
			lit = from.distance_to(p) <= radius and _clear(space, from, p, node)
		if lit:
			node.receive_light(_player.light_mode, delta)

func _in_cone(space: PhysicsDirectSpaceState2D, node: Node, from: Vector2, dir: Vector2, reach: float, half: float) -> bool:
	var p: Vector2 = node.light_target(from)
	var v := p - from
	return v.length() <= reach and absf(dir.angle_to(v)) <= half and _clear(space, from, p, node)

## 视线：from 到 p 之间没有墙，或者第一下打中的就是目标自己（影藤）。
func _clear(space: PhysicsDirectSpaceState2D, from: Vector2, p: Vector2, node: Node) -> bool:
	var hit := _ray(space, from, p)
	return hit.is_empty() or hit.collider == node

func _ray(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, Layers.WALLS))

func _cone_light() -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = Lighting.cone_texture(Game.tuning.focus_half_angle)
	light.color = COLOR
	Lighting.enable_shadows(light)
	return light

## 散射时亮圆形光，聚光时亮锥形光（打到玻璃再加一束反射光）。出生和熄灭时跟着星体淡入淡出。
func _update_lights() -> void:
	var t := Game.tuning
	var a := _player.fade()
	var focus := _player.light_mode == Player.LightMode.FOCUS
	var scale_per_px := 1.0 / (Lighting.TEX * 0.5)
	var radius := t.scatter_radius(_player.light)
	var cone := Lighting.cone_texture(t.focus_half_angle)
	_scatter.visible = a > 0.0 and not focus
	_scatter.energy = a
	_scatter.texture_scale = radius * scale_per_px
	_focus.visible = a > 0.0 and focus
	_focus.energy = FOCUS_ENERGY * a
	_focus.texture = cone
	_focus.rotation = _player.aim.angle()
	_focus.texture_scale = radius * t.focus_range_mult * scale_per_px
	_reflect.visible = _focus.visible and reflecting
	if reflecting:
		_reflect.energy = FOCUS_ENERGY * a
		_reflect.texture = cone
		_reflect.global_position = reflect_from
		_reflect.rotation = reflect_dir.angle()
		_reflect.texture_scale = reflect_range * scale_per_px

## 光环：半径就是散射半径，也就是亮度。聚光时画得更明显；亮度快没了闪红。
func _draw() -> void:
	var a := _player.fade()
	if a <= 0.0:
		return
	var t := Game.tuning
	var focus := _player.light_mode == Player.LightMode.FOCUS
	var c := Color(Player.STAR_COLOR, (0.4 if focus else 0.2) * a)
	if _player.light < _player.light_max * t.low_light_ratio:
		c = Color(Player.WARN_COLOR, (0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.012)) * a)
	draw_arc(Vector2.ZERO, t.scatter_radius(_player.light), 0.0, TAU, 96, c, 1.5, true)
