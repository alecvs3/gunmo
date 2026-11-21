class_name Player
extends CharacterBody2D
## A player's character, named after its owner's peer id and built from components.
## What runs depends on who this peer is to the player:
##   host    simulates it from its owner's input commands; that result is the truth
##   owner   predicts it from the same commands (PlayerPrediction), corrected by the host
##   others  show the host's snapshots, interpolated (NetEntity)
## simulate() is the one tick of player logic all of them share, so they agree.

## How see-through a spawn-protected player is drawn.
const PROTECTED_ALPHA: float = 0.45

@export var player_data: PlayerData

var peer_id: int = 1
## Set by the host before spawning; sent to clients once with the spawn (SpawnSync).
var display_name: String = ""
## Host-run bot (negative peer id). Also spawn-synced, for the scoreboard.
var is_bot: bool = false
## Host: drives a bot instead of a human's input (set by Level.spawn_bot).
var bot: BotController = null
## 0 = the co-op team; any other number is a team of its own (see HitboxComponent.team_for).
var team_id: int = 0:
	set(value):
		team_id = value
		if is_node_ready():
			_hitbox.team = HitboxComponent.team_for(value)
## Spawn protection (Gun Game): can't be hurt, drawn see-through. Replicated.
var is_protected: bool = false:
	set(value):
		is_protected = value
		if is_node_ready():
			_health.invulnerable = value
			$Visual.modulate.a = PROTECTED_ALPHA if value else 1.0
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
@onready var _loadout: PlayerLoadout = $PlayerLoadout
@onready var _wallet: WalletComponent = $WalletComponent
@onready var _score: ScoreComponent = $ScoreComponent
@onready var _knockback: KnockbackComponent = $KnockbackComponent
@onready var _input_source: PlayerInputSource = $PlayerInputSource
@onready var _prediction: PlayerPrediction = $PlayerPrediction


## This peer's own player, if it has one (the HUD and shop read it).
static func find_local(tree: SceneTree) -> Player:
	return find_by_id(tree, tree.get_multiplayer().get_unique_id())


## The player (or bot) with this id on this peer, if there is one.
static func find_by_id(tree: SceneTree, id: int) -> Player:
	for node in tree.get_nodes_in_group(Groups.PLAYERS):
		var player := node as Player
		if player != null and player.peer_id == id:
			return player
	return null


func _enter_tree() -> void:
	peer_id = name.to_int()


func _ready() -> void:
	$Visual/Body.color = Color.from_hsv(fmod(absi(peer_id) * 0.618034, 1.0), 0.55, 0.95)
	_hitbox.owner_id = peer_id
	_hitbox.team = HitboxComponent.team_for(team_id)
	_loadout.configure(player_data)
	_knockback.configure(
		player_data.knockback_friction, player_data.knockback_bounce, player_data.knockback_taken
	)
	_commands.configure(NetworkManager.config)
	var is_owner: bool = peer_id == multiplayer.get_unique_id()
	var camera: PlayerCamera = $PlayerCamera
	camera.enabled = is_owner
	camera.follow_time = player_data.camera_follow_time
	camera.spectate_follow_time = player_data.spectate_follow_time
	$PlayerSpectate.set_process(is_owner)
	$PlayerSpectate.set_process_unhandled_input(is_owner)
	add_to_group(Groups.PLAYERS)
	$Visual/NameLabel.text = display_name
	$Visual/NameLabel.visible = not is_owner
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
	if bot != null:
		_commands.push([bot.next_command()])
	elif peer_id == multiplayer.get_unique_id():
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
	var stats: PlayerData = _loadout.effective_player
	_move_velocity = PlayerMotor.step(_move_velocity, command.move, delta, stats)
	velocity = _move_velocity + _knockback.velocity
	move_and_slide()
	_knockback.bounce_off_collisions(self)
	_knockback.step(delta)
	var wants_fire: bool = command.has(InputCommand.FIRE)
	if _weapon.step(delta, wants_fire, command.has(InputCommand.RELOAD)) and not replaying:
		_fire(command)


## What the HUD shows about this player: health, ammo, reload (0..1, 0 = not reloading).
func hud_stats() -> Dictionary:
	return {
		"health": _health.current_health,
		"max_health": _health.max_health,
		"ammo": _weapon.ammo,
		"magazine": _weapon.weapon_data.magazine_size,
		"reload": _weapon.reload_progress(),
		"credits": _wallet.credits,
	}


func get_wallet() -> WalletComponent:
	return _wallet


func get_loadout() -> PlayerLoadout:
	return _loadout


func get_score() -> ScoreComponent:
	return _score


## Host only: out of the fight without dying (a late joiner spectating until the break).
func make_spectator() -> void:
	_move_velocity = Vector2.ZERO
	_knockback.velocity = Vector2.ZERO
	_set_alive(false)


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
	state.protected = is_protected
	state.team_id = team_id
	state.kills = _score.kills
	state.deaths = _score.deaths
	state.tier = _score.tier
	state.tier_kills = _score.tier_kills
	state.teleport_count = teleport_count
	state.last_command = last_command
	state.weapon_index = _loadout.weapon_index
	state.upgrade_levels = _loadout.levels.duplicate()
	state.credits = _wallet.credits
	return state


## Other clients: show this (interpolated) state.
func apply_net_state(state: NetState) -> void:
	var player_state := state as PlayerNetState
	position = player_state.position
	_pivot.rotation = player_state.aim
	_loadout.load_state(player_state.weapon_index, player_state.upgrade_levels)
	_health.apply_replicated(player_state.health)
	_wallet.apply_replicated(player_state.credits)
	_weapon.ammo = player_state.ammo
	teleport_count = player_state.teleport_count
	is_alive = player_state.alive
	_apply_shared_state(player_state)


## Owner client: the host's verdict on where we are; prediction reconciles with it.
func receive_authoritative_state(_tick: int, state: NetState) -> void:
	_prediction.on_server_state(state as PlayerNetState)


## Owner client: jump back to the host's state before replaying unconfirmed commands.
func restore_from_state(state: PlayerNetState) -> void:
	position = state.position
	_move_velocity = state.move_velocity
	_knockback.velocity = state.knockback
	_loadout.load_state(state.weapon_index, state.upgrade_levels)
	_wallet.apply_replicated(state.credits)
	_weapon.restore(state.ammo, state.cooldown_left, state.reload_left)
	_health.apply_replicated(state.health)
	teleport_count = state.teleport_count
	last_command = state.last_command
	is_alive = state.alive
	_apply_shared_state(state)


## Clients: the parts of a snapshot every peer shows the same way.
func _apply_shared_state(state: PlayerNetState) -> void:
	is_protected = state.protected
	if team_id != state.team_id:
		team_id = state.team_id
	_score.apply_replicated(state.kills, state.deaths, state.tier, state.tier_kills)


func _ready_as_host() -> void:
	_health.reset()
	_health.died.connect(_on_died)
	NetworkManager.channel.commands_received.connect(_on_commands_received)
	add_to_group(Groups.LIVING_PLAYERS)


## One shot from the weapon: a bullet per pellet, each with its own seeded spread. Bullets leave
## the muzzle of the simulated body (not the eased visuals), so the host and the owner compute
## the same origins and directions.
func _fire(command: InputCommand) -> void:
	var origin: Vector2 = global_position + _muzzle.position.rotated(command.aim)
	for pellet in _weapon.weapon_data.pellets:
		_emit_shot(_make_shot(command, origin, Shot.make_id(command.sequence, pellet)))


func _make_shot(command: InputCommand, origin: Vector2, shot_id: int) -> Shot:
	var seed_value: int = WeaponComponent.shot_seed(peer_id, shot_id)
	var direction: Vector2 = _weapon.spread_direction(Vector2.from_angle(command.aim), seed_value)
	var shot: Shot = Shot.from_weapon(_weapon.weapon_data, origin, direction)
	shot.shooter_id = peer_id
	shot.shot_id = shot_id
	shot.team = _hitbox.team
	shot.fire_tick = NetworkManager.clock.server_tick_now()
	shot.view_tick = command.view_tick
	return shot


func _emit_shot(shot: Shot) -> void:
	if multiplayer.is_server():
		EventBus.shot_fired.emit(shot)
	else:
		EventBus.shot_predicted.emit(shot)


func _on_commands_received(sender_id: int, data: PackedByteArray) -> void:
	if sender_id == peer_id:
		_commands.push(InputCommand.decode_batch(data))


func _on_died(killer_id: int) -> void:
	_move_velocity = Vector2.ZERO
	_knockback.velocity = Vector2.ZERO
	_set_alive(false)
	EventBus.player_killed.emit(self, killer_id)


func _set_alive(alive: bool) -> void:
	is_alive = alive
	_hitbox.set_deferred("monitorable", alive)
	if alive:
		add_to_group(Groups.LIVING_PLAYERS)
	else:
		remove_from_group(Groups.LIVING_PLAYERS)
