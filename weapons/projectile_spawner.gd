class_name ProjectileSpawner
extends MultiplayerSpawner
## Turns EventBus.shot_fired into bullets on the host. Clients receive only the spawn data
## (origin, direction, speed...) and move their copy themselves: no per-frame bullet sync.

const BULLET_SCENE: PackedScene = preload("res://weapons/bullet.tscn")


func _ready() -> void:
	spawn_function = _create_bullet
	if multiplayer.is_server():
		EventBus.shot_fired.connect(_on_shot_fired)


func _on_shot_fired(spawn_data: Dictionary) -> void:
	spawn(spawn_data)


func _create_bullet(spawn_data: Variant) -> Node:
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.setup(spawn_data)
	return bullet
