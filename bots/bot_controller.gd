class_name BotController
extends Node
## Host only: the "player" behind a bot. Added to a bot's Player by Level.spawn_bot; every
## physics tick the Player asks it for an InputCommand and simulates that like any human's
## input, so bots move, aim, fire and get replicated exactly like players (rule 3).
## It gathers what the bot can see (anything hittable on another team, so other players in
## Gun Game and enemies in Waves, within its awareness range with a clear line of sight),
## lets BotBrain decide, and adds the profile's human flaws: reaction time, aim error and
## limited turn speed. Out of sight it walks the navigation mesh toward
## where it last saw someone, or roams between the level's respawn points.

## How close to a path point counts as reached.
const PATH_POINT_REACHED: float = 24.0

@export var profile: BotProfile

## The level's respawn points to roam between (set by Level.spawn_bot).
var roam_points: Array[Vector2] = []

var _player: Player
var _rng := RandomNumberGenerator.new()
var _sequence: int = 0
var _aim: float = 0.0
var _target_id: int = 0
var _target_seen_ticks: int = 0
var _last_seen: Vector2 = Vector2.INF
var _aim_error: float = 0.0
var _aim_error_ticks: int = 0
var _strafe_sign: float = 1.0
var _strafe_ticks: int = 0
var _path := PackedVector2Array()
var _path_index: int = 0
var _path_goal: Vector2 = Vector2.INF
var _repath_ticks: int = 0


func _ready() -> void:
	_player = get_parent() as Player
	_rng.randomize()


## One tick of decisions as an input command.
func next_command() -> InputCommand:
	var command := InputCommand.new()
	_sequence += 1
	command.sequence = _sequence
	command.view_tick = NetworkManager.clock.tick
	command.client_tick = NetworkManager.clock.tick
	if _player == null or not _player.is_alive:
		_target_id = 0
		_path = PackedVector2Array()
		command.aim = _aim
		return command
	_tick_timers()
	var target: HitboxComponent = _pick_target()
	if target != null:
		_fight(target, command)
	else:
		_roam(command)
	command.aim = _aim
	return command.sanitized()


func _tick_timers() -> void:
	var rate: float = NetClock.tick_rate()
	_aim_error_ticks -= 1
	if _aim_error_ticks <= 0:
		_aim_error_ticks = maxi(roundi(profile.aim_error_period * rate), 1)
		var spread: float = deg_to_rad(profile.aim_error_degrees)
		_aim_error = _rng.randf_range(-spread, spread)
	_strafe_ticks -= 1
	if _strafe_ticks <= 0:
		_strafe_ticks = maxi(roundi(profile.strafe_period * rate * _rng.randf_range(0.6, 1.4)), 1)
		_strafe_sign = -_strafe_sign
	_repath_ticks -= 1


## Anything hittable on another team: players of other teams (Gun Game) or enemies (Waves).
func _pick_target() -> HitboxComponent:
	var candidates: Array[BotBrain.Candidate] = []
	var by_id: Dictionary = {}
	var own_team: StringName = HitboxComponent.team_for(_player.team_id)
	for hitbox in NetworkManager.lag_compensator.hitboxes():
		if hitbox.team == own_team or not hitbox.is_hittable():
			continue
		var id: int = hitbox.get_instance_id()
		var at: Vector2 = hitbox.center()
		candidates.append(BotBrain.Candidate.new(id, at, _can_see(at)))
		by_id[id] = hitbox
	var chosen: int = BotBrain.choose_target(
		_player.global_position, candidates, profile.awareness_range, _target_id
	)
	if chosen != _target_id:
		_target_seen_ticks = 0
	_target_id = chosen
	if chosen == 0:
		return null
	_target_seen_ticks += 1
	return by_id[chosen]


func _fight(target: HitboxComponent, command: InputCommand) -> void:
	var target_position: Vector2 = target.center()
	var to_target: Vector2 = target_position - _player.global_position
	_last_seen = target_position
	var aim_point: Vector2 = _lead(target)
	var desired: float = (aim_point - _player.global_position).angle() + _aim_error
	_aim = BotBrain.turn_towards(_aim, desired, _turn_step())
	command.move = BotBrain.move_direction(
		_player.global_position,
		target_position,
		profile.preferred_distance,
		profile.strafe,
		_strafe_sign
	)
	var reacted: bool = _target_seen_ticks >= roundi(profile.reaction_time * NetClock.tick_rate())
	var cone: float = deg_to_rad(profile.fire_cone_degrees)
	var in_range: bool = to_target.length() <= _weapon_range()
	if reacted and in_range and BotBrain.aim_ready(_aim, desired, cone):
		command.buttons |= InputCommand.FIRE


## Where to aim at `target`: where it will be when the bullet gets there. A remote human is
## first moved to where their own screen has them (the host sees them their latency late),
## so bots aim at the player the human sees, and a dodge on that screen still works.
func _lead(target: HitboxComponent) -> Vector2:
	var body := target.get_parent() as CharacterBody2D
	var velocity: Vector2 = body.velocity if body != null else Vector2.ZERO
	var position: Vector2 = target.center()
	var human := body as Player
	if human != null:
		position += velocity * human.timeline_lead()
	var weapon: WeaponData = _player.get_loadout().current_weapon()
	return BotBrain.intercept(
		_player.global_position, position, velocity, weapon.bullet_speed, weapon.bullet_lifetime
	)


## Nobody in sight: go where someone was last seen, else to a random respawn point.
func _roam(command: InputCommand) -> void:
	if _last_seen != Vector2.INF and _player.global_position.distance_to(_last_seen) < 40.0:
		_last_seen = Vector2.INF
	var goal: Vector2 = _path_goal
	if _last_seen != Vector2.INF:
		goal = _last_seen
	elif _path_goal == Vector2.INF or _path_index >= _path.size():
		goal = _random_roam_point()
	if goal != _path_goal or _repath_ticks <= 0:
		_plan_path(goal)
	var step: Array = BotBrain.follow_path(
		_player.global_position, _path, _path_index, PATH_POINT_REACHED
	)
	command.move = step[0]
	_path_index = step[1]
	if command.move != Vector2.ZERO:
		_aim = BotBrain.turn_towards(_aim, command.move.angle(), _turn_step())
	var weapon: WeaponComponent = _player.get_loadout().weapon
	if weapon.ammo < weapon.weapon_data.magazine_size:
		command.buttons |= InputCommand.RELOAD


func _plan_path(goal: Vector2) -> void:
	_path_goal = goal
	_repath_ticks = maxi(roundi(profile.repath_interval * NetClock.tick_rate()), 1)
	var map: RID = _player.get_world_2d().navigation_map
	var from: Vector2 = _player.global_position
	_path = PackedVector2Array()
	if NavigationServer2D.map_get_iteration_id(map) != 0:
		_path = NavigationServer2D.map_get_path(map, from, goal, true)
	if _path.is_empty():
		_path = PackedVector2Array([goal])
	_path_index = 0


func _random_roam_point() -> Vector2:
	if roam_points.is_empty():
		return _player.global_position
	return roam_points[_rng.randi_range(0, roam_points.size() - 1)]


func _can_see(point: Vector2) -> bool:
	var from: Vector2 = _player.global_position
	if from.distance_to(point) > profile.awareness_range * BotBrain.KEEP_TARGET_RANGE:
		return false
	var query := PhysicsRayQueryParameters2D.create(from, point, Bullet.WORLD_MASK)
	query.collide_with_areas = false
	return _player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _turn_step() -> float:
	return deg_to_rad(profile.turn_speed_degrees) * NetClock.tick_delta()


## How far its bullets fly.
func _weapon_range() -> float:
	var weapon: WeaponData = _player.get_loadout().current_weapon()
	return weapon.bullet_speed * weapon.bullet_lifetime
