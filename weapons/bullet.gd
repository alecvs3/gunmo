class_name Bullet
extends Area2D
## Flies in a straight line. Only the host's copy detects hits and frees itself;
## clients just move their copy and drop it when the host's despawn arrives.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var damage: int = 0
var shooter_id: int = 0
var _life_left: float = 0.0
var _spent: bool = false


## Everything a bullet needs, taken from the weapon's data. Sent to clients on spawn.
static func make_spawn_data(
	data: WeaponData, origin: Vector2, aim_direction: Vector2, shooter: int
) -> Dictionary:
	return {
		"position": origin,
		"direction": aim_direction.normalized(),
		"speed": data.bullet_speed,
		"lifetime": data.bullet_lifetime,
		"damage": data.damage,
		"shooter_id": shooter,
	}


func setup(spawn_data: Dictionary) -> void:
	position = spawn_data["position"]
	direction = spawn_data["direction"]
	speed = spawn_data["speed"]
	_life_left = spawn_data["lifetime"]
	damage = spawn_data["damage"]
	shooter_id = spawn_data["shooter_id"]
	rotation = direction.angle()


func _ready() -> void:
	var is_host: bool = multiplayer.is_server()
	monitoring = is_host
	if is_host:
		area_entered.connect(apply_hit)
		body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_life_left -= delta
	if _life_left > 0.0:
		return
	if multiplayer.is_server():
		queue_free()
	else:
		hide()
		set_physics_process(false)


## Host only. Damages the first hitbox touched, then the bullet is used up.
func apply_hit(area: Area2D) -> void:
	if _spent or not area is HitboxComponent:
		return
	_spent = true
	(area as HitboxComponent).hit(damage, shooter_id)
	queue_free()


func _on_body_entered(_body: Node2D) -> void:
	_spent = true
	queue_free()
