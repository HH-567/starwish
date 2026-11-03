class_name Shapes
## 实体共用：运行时按 size 新建碰撞形状和遮光形状，每个实例各自一份。

static func add_rect(body: CollisionObject2D, size: Vector2) -> void:
	var rect := RectangleShape2D.new()
	rect.size = size
	var shape := CollisionShape2D.new()
	shape.shape = rect
	body.add_child(shape)

static func add_circle(body: CollisionObject2D, radius: float) -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var shape := CollisionShape2D.new()
	shape.shape = circle
	body.add_child(shape)

## 和碰撞矩形一样大的遮光形状，画面上的阴影和视线判定一致。
static func add_occluder(node: Node2D, size: Vector2) -> void:
	var h := size * 0.5
	var polygon := OccluderPolygon2D.new()
	polygon.polygon = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])
	var occluder := LightOccluder2D.new()
	occluder.occluder = polygon
	node.add_child(occluder)
