class_name Lighting
## 光照共用：不受暗处影响的材质、点光源和锥形光的贴图。
## 开了 dark 的关卡里有 CanvasModulate，没被照到的地方会变暗；
## 自己会发光的东西（小星、哭声、加速带……）用 unshaded() 材质，不受它影响。

## 光照贴图的边长；光源 texture_scale = 半径 ÷ (TEX / 2)。
const TEX := 256
## 地面底色：暗处乘上 ambient 后是深蓝，被暖色光照到时显出暖色。
const FLOOR_COLOR := Color(0.32, 0.3, 0.34)

static var _unshaded: CanvasItemMaterial
static var _radial: GradientTexture2D
static var _cone: ImageTexture
static var _cone_angle := -1.0

static func unshaded() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded

## 圆形光：中间到 60% 半径都比较亮，之后渐暗，光圈边缘看得出半径。
static func radial_texture() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0)])
		_radial = GradientTexture2D.new()
		_radial.gradient = g
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = TEX
		_radial.height = TEX
	return _radial

## 锥形光：顶点在贴图中心，朝 +X 张开 half_angle 度，亮度随距离的变化和圆形光一样。
## 半角变了（F4 重读数值）才重新生成。
static func cone_texture(half_angle: float) -> ImageTexture:
	if _cone != null and is_equal_approx(_cone_angle, half_angle):
		return _cone
	var half := TEX * 0.5
	var edge := deg_to_rad(half_angle)
	var data := PackedByteArray()
	data.resize(TEX * TEX * 4)
	data.fill(255)
	for y in TEX:
		for x in TEX:
			var v := Vector2(x + 0.5 - half, y + 0.5 - half)
			var d := v.length() / half
			var a := 0.0
			if v.x > 0.0 and d < 1.0:
				var radial := 1.0 - 0.25 * d / 0.6 if d < 0.6 else 0.75 * (1.0 - d) / 0.4
				a = radial * (1.0 - smoothstep(edge * 0.7, edge, absf(v.angle())))
			data[(y * TEX + x) * 4 + 3] = int(a * 255.0)
	_cone = ImageTexture.create_from_image(Image.create_from_data(TEX, TEX, false, Image.FORMAT_RGBA8, data))
	_cone_angle = half_angle
	return _cone

## 半径为 radius 的圆形点光源。
static func point_light(radius: float, color: Color, energy := 1.0, shadows := false) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = radial_texture()
	light.texture_scale = radius / (TEX * 0.5)
	light.color = color
	light.energy = energy
	if shadows:
		enable_shadows(light)
	return light

static func enable_shadows(light: PointLight2D) -> void:
	light.shadow_enabled = true
	light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	light.shadow_filter_smooth = 1.5

## 开了 dark 的关卡：没被照到的地方乘 ambient；每个矩形铺一块地面，垫在 parent 的最底下。
## 矩形是 parent 里的坐标。
static func add_darkness(parent: Node, floors: Array[Rect2], ambient := Color.BLACK) -> void:
	var shade := CanvasModulate.new()
	shade.color = ambient if ambient != Color.BLACK else Game.tuning.ambient
	parent.add_child(shade)
	for rect in floors:
		var ground := ColorRect.new()
		ground.color = FLOOR_COLOR
		ground.position = rect.position
		ground.size = rect.size
		ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(ground)
		parent.move_child(ground, 0)
