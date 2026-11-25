class_name ShieldLook
extends EnemyLook
## A Shielder's look: a curved metal plate in front of it, as wide as the arc its shield really
## blocks (keep `arc_degrees` equal to its EnemyShield's), so players can read where to shoot.

## Arc points along the plate (more = smoother).
const STEPS: int = 12

@export var plate_color: Color = Color(0.55, 0.62, 0.72)
@export var rim_color: Color = Color(0.16, 0.18, 0.22)
@export var rivet_color: Color = Color(0.85, 0.88, 0.92)
## Width of the plate (degrees); the same as the shield's blocking arc.
@export_range(10.0, 360.0) var arc_degrees: float = 110.0
## Distance from its centre to the inside of the plate, and the plate's thickness (px).
@export_range(4.0, 60.0) var plate_radius: float = 21.0
@export_range(1.0, 20.0) var thickness: float = 6.0


func draw(canvas: CanvasItem, _speed: float, _windup: float) -> void:
	var plate: PackedVector2Array = outline()
	canvas.draw_colored_polygon(plate, plate_color)
	plate.append(plate[0])
	canvas.draw_polyline(plate, rim_color, 2.0, true)
	var half: float = deg_to_rad(arc_degrees) / 2.0
	var middle: float = plate_radius + thickness / 2.0
	for angle: float in [-half * 0.6, 0.0, half * 0.6]:
		canvas.draw_circle(Vector2.from_angle(angle) * middle, 1.5, rivet_color)


## Pure: the plate's corners: the outer edge across the arc, then the inner edge back.
func outline() -> PackedVector2Array:
	var half: float = deg_to_rad(arc_degrees) / 2.0
	var points := PackedVector2Array()
	for index in STEPS + 1:
		points.append(
			(
				Vector2.from_angle(lerpf(-half, half, index / float(STEPS)))
				* (plate_radius + thickness)
			)
		)
	for index in range(STEPS, -1, -1):
		points.append(Vector2.from_angle(lerpf(-half, half, index / float(STEPS))) * plate_radius)
	return points
