class_name Player
extends CharacterBody2D
## A player's character, named after its owner's peer id and built from components.
## What runs depends on who this peer is to the player:
##   host    simulates it from its owner's input commands; that result is the truth
##   owner   predicts it from the same commands (PlayerPrediction), corrected by the host
##   others  show the host's snapshots, interpolated (NetEntity)
## simulate() is the one tick of player logic all of them share, so they agree.

@export var player_data: PlayerData

var peer_id: int = 1
## Clients hide dead players too (it is replicated).
var is_alive: bool = true:
	set(value):
		is_alive = value
		visible = value
var teleport_count: int = 0
var last_command: int = -1

var _move_velocity: Vector2 = Vector2.ZERO
var _commands := CommandQueue.new()

@onready var _pivot: Node2D = $Visual/Pivot
@onready var _muzzle: Marker2D = $Visual/Pivot/Muzzle
@onready var _health: HealthComponent = $HealthComponent
@onready var _hitbox: HitboxComponent = $HitboxComponent
@onready var _weapon: WeaponComponent = $WeaponComponent
@onready var _knockback: KnockbackComponent = $KnockbackComponent
@onready var _input_source: PlayerInputSource = $PlayerInputSource
@onready var _prediction: PlayerPrediction = $PlayerPrediction


func _enter_tree() -> void:
	peer_id = name.to_int()


func _ready() -> void:
	$Visual/Body.color = Color.from_hsv(fmod(peer_id * 0.618034, 1.0), 0.55, 0.95)
	_health.max_health = player_data.max_health
	_knockback.configure(
		player_data.knockback_friction, player_data.knockback_bounce, player_data.knockback_taken
	)
	_commands.configure(NetworkManager.config)
	var is_owner: bool = peer_id == multiplayer.get_unique_id()
	var camera: PlayerCamera = $PlayerCamera
	camera.enabled = is_owner
	camera.follow_time = player_data.camera_follow_time
	camera.set_process(is_owner)
	camera.set_physics_process(is_owner)
	_input_source.set_process(is_owner)
	_prediction.set_process(is_owner and not multiplayer.is_server())
	if is_owner and not multiplayer.is_server():
		($NetEntity as NetEntity).use_latest_states()
	set_physics_process(multiplayer.is_server() or is_owner)
	if multiplayer.is_server():
		_ready_as_host()


func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		_prediction.run_tick(self)
		return
	if peer_id == multiplayer.get_unique_id():
		_commands.push([_input_source.next_command()])
	for command in _commands.take_for_tick():
		simulate(command, false)


## One tick of this player for one input command. Identical on the host and the predicting
## owner; `replaying` is true when the owner re-runs a command after a correction (so shots
## already shown are not shown twice).
func simulate(command: InputCommand, replaying: bool) -> void:
	last_command = command.sequence
	if not is_alive:
		return
	var delta: float = NetClock.tick_delta()
	_pivot.rotation = command.aim
	_move_velocity = PlayerMotor.step(_move_velocity, command.move, delta, player_data)
	velocity = _move_velocity + _knockback.velocity
	move_and_slide()
	_knockback.bounce_off_collisions(self)
	_knockback.step(delta)
	var wants_fire: bool = command.has(InputCommand.FIRE)
	if _weapon.step(delta, wants_fire, command.has(InputCommand.RELOAD)) and not replaying:
		_fire(command)


## Host only.
func respawn(at: Vector2) -> void:
	position = at
	_move_velocity = Vector2.ZERO
	_knockback.velocity = Vector2.ZERO
	teleport_count = (teleport_count + 1) & 0xFF
	reset_physics_interpolation()
	_health.reset()
	_set_alive(true)


func capture_net_state() -> NetState:
	var state := PlayerNetState.new()
	state.position = position
	state.move_velocity = _move_velocity
	state.knockback = _knockback.velocity
	state.aim = _pivot.rotation
	state.health = _health.current_health
	state.ammo = _weapon.ammo
	state.cooldown_left = _weapon.cooldown_left
	state.reload_left = _weapon.reload_left
	state.alive = is_alive
	state.teleport_count = teleport_count
	state.last_command = last_command
	return state


## Other clients: show this (interpolated) state.
func apply_net_state(state: NetState) -> void:
	var player_state := state as PlayerNetState
	position = player_state.position
	_pivot.rotation = player_state.aim
	_health.apply_replicated(player_state.health)
	_weapon.ammo = player_state.ammo
	teleport_count = player_state.teleport_count
	is_alive = player_state.alive


## Owner client: the host's verdict on where we are; prediction reconciles with it.
func receive_authoritative_state(_tick: int, state: NetState) -> void:
	_prediction.on_server_state(state as PlayerNetState)


## Owner client: jump back to the host's state before replaying unconfirmed commands.
func restore_from_state(state: PlayerNetState) -> void:
	position = state.position
	_move_velocity = state.move_velocity
	_knockback.velocity = state.knockback
	_weapon.restore(state.ammo, state.cooldown_left, state.reload_left)
	_health.apply_replicated(state.health)
	teleport_count = state.teleport_count
	last_command = state.last_command
	is_alive = state.alive


func _ready_as_host() -> void:
	_health.reset()
	_health.died.connect(_on_died)
	NetworkManager.channel.commands_received.connect(_on_commands_received)
	add_to_group(Groups.LIVING_PLAYERS)
	EventBus.player_spawned.emit(self)


## The bullet leaves the muzzle of the simulated body (not the eased visuals), so the host and
## the owner compute the same origin.
func _fire(command: InputCommand) -> void:
	var origin: Vector2 = global_position + _muzzle.position.rotated(command.aim)
	var seed_value: int = WeaponComponent.shot_seed(peer_id, command.sequence)
	var direction: Vector2 = _weapon.spread_direction(Vector2.from_angle(command.aim), seed_value)
	var shot: Shot = Shot.from_weapon(_weapon.weapon_data, origin, direction)
	shot.shooter_id = peer_id
	shot.shot_id = command.sequence
	shot.team = _hitbox.team
	shot.fire_tick = NetworkManager.clock.server_tick_now()
	shot.view_tick = command.view_tick
	if multiplayer.is_server():
		EventBus.shot_fired.emit(shot)
	else:
		EventBus.shot_predicted.emit(shot)


func _on_commands_received(sender_id: int, data: PackedByteArray) -> void:
	if sender_id == peer_id:
		_commands.push(InputCommand.decode_batch(data))


func _on_died(_killer_id: int) -> void:
	_move_velocity = Vector2.ZERO
	_knockback.velocity = Vector2.ZERO
	_set_alive(false)
	EventBus.player_died.emit(peer_id)


func _set_alive(alive: bool) -> void:
	is_alive = alive
	_hitbox.set_deferred("monitorable", alive)
	if alive:
		add_to_group(Groups.LIVING_PLAYERS)
	else:
		remove_from_group(Groups.LIVING_PLAYERS)
