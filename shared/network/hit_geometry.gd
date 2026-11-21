class_name HitGeometry
extends RefCounted
## Swept hit tests: where along a moving point's path (from -> to) it first touches a shape.
## Results are fractions 0..1 of the path; 0 means it starts inside; -1 means no hit.
## Testing the whole path each tick means fast bullets can't skip through thin targets.


static func segment_circle(from: Vector2, to: Vector2, center: Vector2, radius: float) -> float:
	var offset: Vector2 = from - center
	var c: float = offset.length_squared() - radius * radius
	if c <= 0.0:
		return 0.0
	var path: Vector2 = to - from
	var a: float = path.length_squared()
	if is_zero_approx(a):
		return -1.0
	var b: float = 2.0 * offset.dot(path)
	var discriminant: float = b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var t: float = (-b - sqrt(discriminant)) / (2.0 * a)
	return t if t >= 0.0 and t <= 1.0 else -1.0


static func segment_rect(from: Vector2, to: Vector2, rect: Rect2) -> float:
	if rect.has_point(from):
		return 0.0
	var path: Vector2 = to - from
	var t_enter: float = 0.0
	var t_exit: float = 1.0
	for axis in 2:
		if is_zero_approx(path[axis]):
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return -1.0
			continue
		var t1: float = (rect.position[axis] - from[axis]) / path[axis]
		var t2: float = (rect.end[axis] - from[axis]) / path[axis]
		t_enter = maxf(t_enter, minf(t1, t2))
		t_exit = minf(t_exit, maxf(t1, t2))
		if t_enter > t_exit:
			return -1.0
	return t_enter
