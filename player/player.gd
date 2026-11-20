class_name Player
extends CharacterBody2D
## A player's character, named after its owner's peer id. The owner only writes PlayerInput;
## the host moves, aims and shoots, and StateSync replicates the result to everyone.

const MIN_AIM_DISTANCE: float = 4.0

@export var player_data: PlayerData

var peer_id: int = 1
## Synced by StateSync, so clients hide dead players too.
var is_alive: bool = true:
	set(value):
		is_alive = value
		visible = value

@onready var _input: PlayerInput = $InputSync
@onready var _pivot: Node2D = $Pivot
@onready var _muzzle: Marker2D = $Pivot/Muzzle
@onready var _health: HealthComponent = $HealthComponent
@onready var _hitbox: HitboxComponent = $HitboxComponent
@onready var _weapon: WeaponComponent = $WeaponComponent


func _enter_tree() -> void:
	peer_id = name.to_int()
	$InputSync.set_multiplayer_authority(peer_id)


func _ready() -> void:
	$Body.color = Color.from_hsv(fmod(peer_id * 0.618034, 1.0), 0.55, 0.95)
	_health.max_health = player_data.max_health
	var is_local: bool = peer_id == multiplayer.get_unique_id()
	($Camera2D as Camera2D).enabled = is_local
	($NetSmoother as NetSmoother).is_local = is_local
	if not multiplayer.is_server():
		set_physics_process(false)
		return
	_health.reset()
	_health.died.connect(_on_died)
	_weapon.fired.connect(_on_weapon_fired)
	add_to_group(Groups.LIVING_PLAYERS)
	EventBus.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	# Input comes from the client: never trust it to be finite.
	var move: Vector2 = _input.move_direction if _input.move_direction.is_finite() else Vector2.ZERO
	velocity = PlayerMotor.step(velocity, move, delta, player_data)
	move_and_slide()
	var aim_offset: Vector2 = _input.aim_position - global_position
	if aim_offset.is_finite() and aim_offset.length() > MIN_AIM_DISTANCE:
		_pivot.rotation = aim_offset.angle()
	if _input.reload_held:
		_weapon.start_reload()
	if _input.fire_held:
		_weapon.try_fire(_muzzle.global_position, Vector2.from_angle(_pivot.rotation))


## Host only.
func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	reset_physics_interpolation()
	_health.reset()
	_set_alive(true)


func _on_died(_killer_id: int) -> void:
	velocity = Vector2.ZERO
	_set_alive(false)
	EventBus.player_died.emit(peer_id)


func _on_weapon_fired(origin: Vector2, direction: Vector2) -> void:
	EventBus.shot_fired.emit(
		Bullet.make_spawn_data(_weapon.weapon_data, origin, direction, peer_id)
	)


func _set_alive(alive: bool) -> void:
	is_alive = alive
	_hitbox.set_deferred("monitorable", alive)
	if alive:
		add_to_group(Groups.LIVING_PLAYERS)
	else:
		remove_from_group(Groups.LIVING_PLAYERS)
