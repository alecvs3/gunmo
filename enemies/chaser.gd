class_name ChaserEnemy
extends CharacterBody2D
## One scene for every enemy type. It targets the nearest living player; its EnemyData decides
## the numbers (speed, health, color...) and the behaviours: where it walks (movement) and how
## it hurts players (attack).
## The AI runs only on the host; clients show its snapshots, interpolated (NetEntity).

## Where clients may load enemy data from (the path arrives from the host at spawn).
const DATA_FOLDER: String = "res://enemies/data/"
## Hitbox and shot team (enemies never hurt each other).
const TEAM: StringName = &"enemies"
## Walls, for line of sight.
const WORLD_MASK: int = 1

## How fast the sprite turns towards its facing (higher = snappier). Looks only.
@export_range(1.0, 60.0) var turn_rate: float = 12.0
## Set before the enemy enters the tree; its path is sent to clients with the spawn.
@export var enemy_data: EnemyData:
	set(value):
		enemy_data = value
		data_path = value.resource_path if value != null else ""

## Synced once at spawn, so clients play the same type.
var data_path: String = ""
## The wave's modifiers (ModifierCatalog bitmask); set before spawning, synced once.
var modifier_mask: int = 0

var _attack_cooldown_left: float = 0.0
var _shots_fired: int = 0
var _repath_left: float = 0.0
var _speed: float = 0.0
var _regen_per_second: float = 0.0
var _regen_carry: float = 0.0
## Host: where it faces (walking direction plus any flinch).
var _facing := EnemyFacing.new()
## The angle the sprite turns towards: the host's own, or the latest from a snapshot.
var _facing_target: float = 0.0

@onready var _body: Sprite2D = $Body
@onready var _health: HealthComponent = $HealthComponent
@onready var _knockback: KnockbackComponent = $KnockbackComponent
@onready var _contact_area: Area2D = $ContactArea
@onready var _agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	if not multiplayer.is_server():
		_load_data_from_host()
	_apply_modifiers(ModifierCatalog.load_default().combined(modifier_mask))
	_knockback.configure(
		enemy_data.knockback_friction, enemy_data.knockback_bounce, enemy_data.knockback_taken
	)
	if not multiplayer.is_server():
		set_physics_process(false)
		_contact_area.monitoring = false
		return
	_health.reset()
	_health.died.connect(_on_died)
	_facing.configure(enemy_data.flinch_degrees, enemy_data.flinch_recovery)
	_knockback.pushed.connect(_facing.flinch_from)


func _physics_process(delta: float) -> void:
	_regenerate(delta)
	var target: Node2D = _find_nearest_target()
	_move(target, delta)
	_attack(target, delta)


## Every peer turns the sprite smoothly towards the facing (where it walks, plus flinches).
## Not towards where it moves: a push would spin it around.
func _process(delta: float) -> void:
	var weight: float = 1.0 - exp(-turn_rate * delta)
	_body.rotation = lerp_angle(_body.rotation, _facing_target, weight)


func capture_net_state() -> NetState:
	var state := EnemyNetState.new()
	state.position = position
	state.health = _health.current_health
	state.facing = EnemyNetState.to_facing(_facing_target)
	return state


func apply_net_state(state: NetState) -> void:
	var enemy_state := state as EnemyNetState
	position = enemy_state.position
	_health.apply_replicated(enemy_state.health)
	_facing_target = EnemyNetState.facing_angle(enemy_state.facing)
	visible = true


func _move(target: Node2D, delta: float) -> void:
	var chase: Vector2 = Vector2.ZERO
	if target != null:
		var goal: Vector2 = enemy_data.movement.goal(global_position, target.global_position)
		if global_position.distance_squared_to(goal) > 1.0:
			chase = _direction_towards(goal, delta) * _speed
	velocity = chase + _knockback.velocity
	move_and_slide()
	_knockback.bounce_off_collisions(self)
	_knockback.step(delta)
	_facing.walk_towards(chase)
	_facing.step(delta)
	_facing_target = _facing.angle()


## Along the navigation path around obstacles. Straight at the target while there is no path
## (the baked map reaches the navigation server a few physics frames after the level starts).
func _direction_towards(target_position: Vector2, delta: float) -> Vector2:
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = enemy_data.repath_interval
		_agent.target_position = target_position
	var map: RID = _agent.get_navigation_map()
	if NavigationServer2D.map_get_iteration_id(map) == 0 or _agent.is_navigation_finished():
		return global_position.direction_to(target_position)
	var next: Vector2 = _agent.get_next_path_position()
	if next.is_equal_approx(global_position):
		return global_position.direction_to(target_position)
	return global_position.direction_to(next)


func _find_nearest_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for candidate: Node2D in get_tree().get_nodes_in_group(Groups.LIVING_PLAYERS):
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _attack(target: Node2D, delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	if _attack_cooldown_left > 0.0:
		return
	var attack: EnemyAttack = enemy_data.attack
	var distance: float = INF
	if target != null:
		distance = global_position.distance_to(target.global_position)
	var can_see: bool = target != null
	if can_see and attack.needs_line_of_sight():
		can_see = _can_see(target)
	if not attack.wants_to_attack(_attack_cooldown_left, distance, can_see):
		return
	if attack.perform(self, target, _touching_hitboxes()):
		_attack_cooldown_left = attack.interval


## The id its shots carry (negative: enemy bullets get fair dodging, see Shot).
func shooter_id() -> int:
	return Shot.enemy_shooter_id($NetEntity.net_id)


func next_shot_id() -> int:
	_shots_fired += 1
	return _shots_fired


## No wall between it and the target.
func _can_see(target: Node2D) -> bool:
	if target == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(
		global_position, target.global_position, WORLD_MASK
	)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Player hitboxes in the contact area.
func _touching_hitboxes() -> Array[HitboxComponent]:
	var touching: Array[HitboxComponent] = []
	for area in _contact_area.get_overlapping_areas():
		var hitbox := area as HitboxComponent
		if hitbox != null:
			touching.append(hitbox)
	return touching


func _on_died(killer_peer_id: int) -> void:
	EventBus.enemy_killed.emit(self, killer_peer_id)
	queue_free()


## The wave's modifiers change health, speed, armor and regeneration, and tint the enemy so
## players can read the wave (every peer tints; only the host's numbers matter).
func _apply_modifiers(combined: WaveModifier) -> void:
	var tinted: Color = enemy_data.color
	if modifier_mask != 0:
		tinted = enemy_data.color.lerp(combined.color, 0.45)
	_body.modulate = tinted
	_body.scale = Vector2.ONE * enemy_data.visual_scale
	_health.max_health = combined.scaled_health(enemy_data.max_health)
	_health.damage_taken_multiplier = combined.damage_taken_multiplier
	_speed = enemy_data.move_speed * combined.speed_multiplier
	_regen_per_second = combined.regen_per_second


## Host: heal a share of max health per second (whole points; the rest carries over).
func _regenerate(delta: float) -> void:
	if _regen_per_second <= 0.0 or _health.current_health >= _health.max_health:
		return
	_regen_carry += _regen_per_second * _health.max_health * delta
	var whole: int = floori(_regen_carry)
	if whole > 0:
		_regen_carry -= whole
		_health.heal(whole)


## Clients: the host told us which type this is; only enemy data files are accepted.
func _load_data_from_host() -> void:
	if not data_path.begins_with(DATA_FOLDER) or not ResourceLoader.exists(data_path):
		return
	var loaded := load(data_path) as EnemyData
	if loaded != null:
		enemy_data = loaded
