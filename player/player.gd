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
## Downed players are drawn greyed out.
const DOWNED_TINT := Color(0.45, 0.45, 0.5, 0.8)
const REVIVE_COLOR := Color(0.35, 1.0, 0.5, 0.9)

@export var player_data: PlayerData

var peer_id: int = 1
## Set by the host before spawning; sent to clients once with the spawn (SpawnSync).
var display_name: String = ""
## Host-run bot (negative peer id). Also spawn-synced, for the scoreboard.
var is_bot: bool = false
## Host: drives a bot instead of a human's input (set by Level.spawn_bot).
var bot: BotController = null
## Host, remote human players only: where their own inputs put them (fair dodging).
var timeline: PlayerTimeline = null
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
## Clients hide dead players too (it is replicated). A downed player stays visible.
var is_alive: bool = true:
	set(value):
		is_alive = value
		visible = value or down_left > 0
## Co-op downed (replicated, set by the mode): bleed-out time left as a share (1..255; 0 = not
## downed), and how full a teammate's revive is (0..255). Downed players lie greyed where
## they fell, with the revive ring over them.
var down_left: int = 0:
	set(value):
		down_left = value
		visible = is_alive or value > 0
		if is_node_ready():
			$Visual.modulate = DOWNED_TINT if value > 0 else Color(1, 1, 1, $Visual.modulate.a)
var revive_progress: int = 0:
	set(value):
		revive_progress = value
		_revive_ring.progress = value / 255.0
## Host: the buttons of the last command simulated (the mode reads REVIVE from it).
var held_buttons: int = 0
var teleport_count: int = 0
## The aim being simulated (the pivot's drawn rotation may lag behind it on the host).
var aim: float = 0.0
var last_command: int = -1
## Simulated walking velocity (knockback comes on top). Part of the snapshot (PlayerNetSync).
var move_velocity: Vector2 = Vector2.ZERO

var _commands := CommandQueue.new()
var _revive_ring := EnemyTelegraph.new()


## What the HUD shows about a player (hud_stats).
class HudStats:
	var health: int = 0
	var max_health: int = 0
	var ammo: int = 0
	var magazine: int = 0
	## 0..1 while reloading, 0 when not.
	var reload: float = 0.0
	var credits: int = 0


@onready var _pivot: Node2D = $Visual/Pivot
@onready var _look: PlayerLook = $Visual/Pivot/Look
@onready var _health: HealthComponent = $HealthComponent
@onready var _hitbox: HitboxComponent = $HitboxComponent
@onready var _weapon: WeaponComponent = $WeaponComponent
@onready var _loadout: PlayerLoadout = $PlayerLoadout
@onready var _wallet: WalletComponent = $WalletComponent
@onready var _score: ScoreComponent = $ScoreComponent
@onready var _knockback: KnockbackComponent = $KnockbackComponent
@onready var _input_source: PlayerInputSource = $PlayerInputSource
@onready var _prediction: PlayerPrediction = $PlayerPrediction
@onready var _display_delay: DisplayDelay = $DisplayDelay
@onready var _net_sync: PlayerNetSync = $PlayerNetSync


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


func _exit_tree() -> void:
	if multiplayer.is_server():
		NetworkManager.stats.peer_inputs.erase(peer_id)


func _enter_tree() -> void:
	peer_id = name.to_int()


func _ready() -> void:
	_revive_ring.color = REVIVE_COLOR
	add_child(_revive_ring)
	_look.character = player_data.look_for(peer_id)
	_hitbox.owner_id = peer_id
	($NetEntity as NetEntity).owner_peer = peer_id
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
	camera.view_size = player_data.view_size
	camera.view_max_crop = player_data.view_max_crop
	$PlayerSpectate.set_process(is_owner)
	$PlayerSpectate.set_process_unhandled_input(is_owner)
	add_to_group(Groups.PLAYERS)
	$Visual/NameLabel.text = display_name
	$Visual/NameLabel.visible = not is_owner
	camera.set_process(is_owner)
	camera.set_physics_process(is_owner)
	_input_source.set_process(is_owner)
	_prediction.set_process(is_owner and not multiplayer.is_server())
	$OwnPlayerDrawing.set_process(is_owner)
	$OwnPlayerDrawing.set_physics_process(is_owner)
	_display_delay.enabled = not is_owner
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
		if timeline != null:
			var hittable: bool = is_alive and _hitbox.monitorable
			timeline.record(
				command.client_tick, NetworkManager.clock.tick, _hitbox.center(), hittable
			)
	if bot == null and peer_id != multiplayer.get_unique_id():
		NetworkManager.stats.report_inputs(peer_id, display_name, _commands)


## One tick of this player for one input command. Identical on the host and the predicting
## owner; `replaying` is true when the owner re-runs a command after a correction (so shots
## already shown are not shown twice).
func simulate(command: InputCommand, replaying: bool) -> void:
	last_command = command.sequence
	held_buttons = command.buttons
	if not is_alive:
		return
	var delta: float = NetClock.tick_delta()
	aim = command.aim
	_pivot.rotation = aim
	var stats: PlayerData = _loadout.effective_player
	move_velocity = PlayerMotor.step(move_velocity, command.move, delta, stats)
	velocity = move_velocity + _knockback.velocity
	move_and_slide()
	_knockback.bounce_off_collisions(self)
	_knockback.step(delta)
	var wants_fire: bool = command.has(InputCommand.FIRE)
	if _weapon.step(delta, wants_fire, command.has(InputCommand.RELOAD)) and not replaying:
		_fire(command)


## What the HUD shows about this player.
func hud_stats() -> HudStats:
	var stats := HudStats.new()
	stats.health = _health.current_health
	stats.max_health = _health.max_health
	stats.ammo = _weapon.ammo
	stats.magazine = _weapon.weapon_data.magazine_size
	stats.reload = _weapon.reload_progress()
	stats.credits = _wallet.credits
	return stats


func get_wallet() -> WalletComponent:
	return _wallet


func get_loadout() -> PlayerLoadout:
	return _loadout


func get_score() -> ScoreComponent:
	return _score


func get_hitbox() -> HitboxComponent:
	return _hitbox


## Host: how far this player's own screen is ahead of where the host has them now (seconds).
## Bots lead them by it.
func timeline_lead() -> float:
	return 0.0 if timeline == null else timeline.lead(NetworkManager.clock.tick)


## Host only: out of the fight without dying (a late joiner spectating until the break).
func make_spectator() -> void:
	move_velocity = Vector2.ZERO
	_knockback.velocity = Vector2.ZERO
	_set_alive(false)


## Where the held gun's barrel ends, relative to the body, before turning by the aim.
func muzzle_offset() -> Vector2:
	return _look.muzzle_for(_weapon.weapon_data.pose)


func is_downed() -> bool:
	return down_left > 0


## Host only: down at 0 health (co-op). Stays where it fell; enemies ignore it.
func go_down() -> void:
	down_left = 255
	revive_progress = 0


## Host only: a teammate revived us where we lie, with `health_share` of our max health.
func revive_here(health_share: float) -> void:
	down_left = 0
	revive_progress = 0
	_health.reset()
	_health.set_health(roundi(_health.max_health * health_share))
	_set_alive(true)


## Host only: bled out; out of the fight until the break.
func bleed_out() -> void:
	down_left = 0
	revive_progress = 0


## Host only.
func respawn(at: Vector2) -> void:
	position = at
	move_velocity = Vector2.ZERO
	_knockback.velocity = Vector2.ZERO
	teleport_count = (teleport_count + 1) & 0xFF
	reset_physics_interpolation()
	_display_delay.snap()
	_health.reset()
	down_left = 0
	revive_progress = 0
	_set_alive(true)


## NetEntity's calls; the snapshot itself is PlayerNetSync's job.
func capture_net_state() -> NetState:
	return _net_sync.capture()


## Other clients: show this (interpolated) state.
func apply_net_state(state: NetState) -> void:
	_net_sync.show_state(state as PlayerNetState)


## Owner client: the host's verdict on where we are; prediction reconciles with it.
func receive_authoritative_state(_tick: int, state: NetState) -> void:
	_prediction.on_server_state(state as PlayerNetState)


## Owner client: jump back to the host's state before replaying unconfirmed commands.
func restore_from_state(state: PlayerNetState) -> void:
	_net_sync.restore(state)


func _ready_as_host() -> void:
	_health.reset()
	_health.died.connect(_on_died)
	NetworkManager.channel.commands_received.connect(_on_commands_received)
	if bot == null and peer_id != multiplayer.get_unique_id():
		timeline = PlayerTimeline.new(NetworkManager.lag_compensator.max_rewind_ticks())
	add_to_group(Groups.LIVING_PLAYERS)


## One shot from the weapon: a bullet per pellet, each with its own seeded spread. Bullets leave
## the drawn barrel of the held weapon, placed on the simulated body (not the eased visuals), so
## the host and the owner compute the same origins and directions.
func _fire(command: InputCommand) -> void:
	var muzzle: Vector2 = _look.muzzle_for(_weapon.weapon_data.pose)
	var origin: Vector2 = global_position + muzzle.rotated(command.aim)
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
		_commands.push(InputCommand.decode_batch(data), Time.get_ticks_usec() / 1000000.0)


func _on_died(killer_id: int) -> void:
	move_velocity = Vector2.ZERO
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
