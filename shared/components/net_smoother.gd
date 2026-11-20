class_name NetSmoother
extends Node
## Makes a networked Node2D glide between position updates instead of jittering.
## The host copies its parent's position into target_position every physics frame and the
## owner's StateSync replicates it. Clients move the parent toward it, and snap on big jumps
## (spawns, respawns). The client's own player uses a faster rate (is_local) so it stays
## close to the host's position without stuttering on uneven packet arrival.
## Client prediction (#7) will replace this for the local player.

## Synced from the host.
var target_position: Vector2 = Vector2.ZERO
## Set by Player for the peer's own character.
var is_local: bool = false

@onready var _body: Node2D = get_parent()


## On clients the synchronizer has already set target_position by now.
func _ready() -> void:
	if multiplayer.is_server():
		target_position = _body.position
	else:
		_body.position = target_position
		_body.reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		target_position = _body.position
	else:
		step_toward_target(delta)


## Client side: one frame of gliding (or snapping) toward target_position.
## A big jump is a teleport, so physics interpolation is reset instead of sliding there.
func step_toward_target(delta: float) -> void:
	var config: NetworkConfig = NetworkManager.config
	if _body.position.distance_to(target_position) > config.snap_distance:
		_body.position = target_position
		_body.reset_physics_interpolation()
		return
	var rate: float = config.local_smoothing_rate if is_local else config.smoothing_rate
	_body.position = _body.position.lerp(target_position, 1.0 - exp(-rate * delta))
