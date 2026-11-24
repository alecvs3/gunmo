class_name ShopGunPicture
extends Control
## A gun's own drawn model (`WeaponData.held_model`, Polygon2D shapes) shown big and centered in
## this box, for the shop's gun cards. Looks only.

## Empty space kept around the gun, as a share of the box.
const MARGIN: float = 0.12

var model: PackedScene:
	set(value):
		if value != model:
			model = value
			_replace_model()

var _model: Node2D


## The area the polygons of `root` (and its Polygon2D children) cover, in `root`'s space.
static func model_bounds(root: Node2D) -> Rect2:
	var bounds := Rect2()
	var first: bool = true
	for node in root.find_children("*", "Polygon2D", true, false):
		var shape := node as Polygon2D
		var to_root: Transform2D = _transform_to(root, shape)
		for point in shape.polygon:
			var placed: Vector2 = to_root * (point + shape.offset)
			if first:
				bounds = Rect2(placed, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(placed)
	return bounds


## From `shape`'s space to `root`'s (works outside the scene tree too).
static func _transform_to(root: Node2D, shape: Node2D) -> Transform2D:
	var to_root := Transform2D.IDENTITY
	var node: Node = shape
	while node != root and node is Node2D:
		to_root = (node as Node2D).transform * to_root
		node = node.get_parent()
	return to_root


## The scale that fits `bounds` inside `box` with MARGIN left around it.
static func fit_scale(bounds: Rect2, box: Vector2) -> float:
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 1.0
	var room: Vector2 = box * (1.0 - 2.0 * MARGIN)
	return maxf(minf(room.x / bounds.size.x, room.y / bounds.size.y), 0.01)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit()


func _replace_model() -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	if model != null:
		_model = model.instantiate() as Node2D
		add_child(_model)
	_fit()


func _fit() -> void:
	if _model == null:
		return
	_model.transform = Transform2D.IDENTITY
	var bounds: Rect2 = model_bounds(_model)
	var factor: float = fit_scale(bounds, size)
	_model.scale = Vector2.ONE * factor
	_model.position = size / 2.0 - bounds.get_center() * factor
