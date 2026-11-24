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
## Tint on top of its colour while slowed.
const FROSTED := Color(0.65, 0.85, 1.3)

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
## Host: slowed and hexed by pets (EnemyStatus). Clients: the flags from the snapshot.
var status := EnemyStatus.new()

var _attack_cooldown_left: float = 0.0
var _shots_fired: int = 0
## Host: the boss phase it is in (always 0 for other enemies).
var _phase: int = 0
## Host: seconds left of a telegraphed attack's windup (0 = not winding up), and its length.
var _windup_left: float = 0.0
var _windup_total: float = 0.0
## Every peer: the ring that shows a windup (the host's own, or from snapshots).
var _telegraph := EnemyTelegraph.new()
var _status_flags: int = 0
var _base_damage_taken: float = 1.0
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
	_scale_body(enemy_data.body_scale)
	add_child(_telegraph)
	if enemy_data.is_boss():
		add_to_group(Groups.BOSSES)
	if not multiplayer.is_server():
		set_physics_process(false)
		_contact_area.monitoring = false
		return
	_health.reset()
	_health.died.connect(_on_died)
	_health.damaged.connect(
		func(amount: int, source_id: int) -> void:
			EventBus.enemy_damaged.emit(self, amount, source_id)
	)
	add_to_group(Groups.ENEMIES)
	_facing.configure(enemy_data.flinch_degrees, enemy_data.flinch_recovery)
	_knockback.pushed.connect(_facing.flinch_from)


func _physics_process(delta: float) -> void:
	_regenerate(delta)
	var now: int = NetworkManager.clock.tick
	_health.damage_taken_multiplier = _base_damage_taken * status.damage_factor(now)
	_show_status(status.flags(now))
	_phase = phase_index()
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
	state.telegraph = EnemyNetState.to_telegraph(_windup_left, _windup_total)
	state.status = status.flags(NetworkManager.clock.tick)
	return state


func apply_net_state(state: NetState) -> void:
	var enemy_state := state as EnemyNetState
	position = enemy_state.position
	_health.apply_replicated(enemy_state.health)
	_facing_target = EnemyNetState.facing_angle(enemy_state.facing)
	_telegraph.progress = enemy_state.telegraph / float(EnemyNetState.TELEGRAPH_STEPS)
	_show_status(enemy_state.status)
	visible = true


## Every peer: slowed enemies look frosty, hexed ones wear a purple mark.
func _show_status(flags: int) -> void:
	if flags == _status_flags:
		return
	_status_flags = flags
	_body.self_modulate = FROSTED if flags & EnemyStatus.FLAG_SLOWED else Color.WHITE
	_telegraph.hexed = flags & EnemyStatus.FLAG_HEXED != 0


func hitbox() -> HitboxComponent:
	return $HitboxComponent


## Share of its health left (0..1), on every peer (clients get health in snapshots).
func health_share() -> float:
	return float(_health.current_health) / maxf(_health.max_health, 1.0)


## A boss's phase from its health (the same on every peer); 0 for other enemies.
func phase_index() -> int:
	return BossPhase.index_for(enemy_data.phases, health_share())


func _move(target: Node2D, delta: float) -> void:
	var chase: Vector2 = Vector2.ZERO
	if target != null:
		var movement: EnemyMovement = enemy_data.movement_in(_phase)
		var goal: Vector2 = movement.goal(global_position, target.global_position)
		if global_position.distance_squared_to(goal) > 1.0:
			var slow: float = status.speed_factor(NetworkManager.clock.tick)
			chase = _direction_towards(goal, delta) * _speed * enemy_data.speed_in(_phase) * slow
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


## A telegraphed attack winds up first (every peer sees the ring fill), then fires.
func _attack(target: Node2D, delta: float) -> void:
	var attack: EnemyAttack = enemy_data.attack_in(_phase)
	if _windup_left > 0.0:
		_windup_left = maxf(_windup_left - delta, 0.0)
		if _windup_left <= 0.0:
			_attack_cooldown_left = attack.interval
			attack.perform(self, target, _touching_hitboxes())
		_telegraph.progress = (
			EnemyNetState.to_telegraph(_windup_left, _windup_total)
			/ float(EnemyNetState.TELEGRAPH_STEPS)
		)
		return
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	if _attack_cooldown_left > 0.0:
		return
	var distance: float = INF
	if target != null:
		distance = global_position.distance_to(target.global_position)
	var can_see: bool = target != null
	if can_see and attack.needs_line_of_sight():
		can_see = _can_see(target)
	if not attack.wants_to_attack(_attack_cooldown_left, distance, can_see):
		return
	if attack.windup > 0.0:
		_windup_left = attack.windup
		_windup_total = attack.windup
	elif attack.perform(self, target, _touching_hitboxes()):
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


## Bosses are bigger: hitbox, touch area and body grow with body_scale (every peer).
func _scale_body(factor: float) -> void:
	if is_equal_approx(factor, 1.0):
		return
	$HitboxComponent.scale_size(factor)
	$HitboxComponent/CollisionShape2D.scale = Vector2.ONE * factor
	$ContactArea/CollisionShape2D.scale = Vector2.ONE * factor
	$CollisionShape2D.scale = Vector2.ONE * factor
	_telegraph.radius *= factor


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
	if enemy_data.split_into != null and enemy_data.split_count > 0:
		EventBus.enemy_split.emit(self, enemy_data.split_into, enemy_data.split_count)
	remove_from_group(Groups.ENEMIES)
	queue_free()


## Where it is drawn (the host draws remote things a little back, see DisplayDelay).
func drawn_position() -> Vector2:
	return _body.global_position


## The colour its death burst uses: its body tint (wave modifiers included).
func burst_color() -> Color:
	return _body.modulate


## Host: whether it has lost health (support enemies heal these).
func is_wounded() -> bool:
	return _health.current_health < _health.max_health


## Host: heal `amount` points (support enemies), less if it resists healing (heal_received).
func heal(amount: int) -> void:
	_health.heal(enemy_data.received_heal(amount))


func max_health() -> int:
	return _health.max_health


## The wave's modifiers change health, speed, armor and regeneration, and tint the enemy so
## players can read the wave (every peer tints; only the host's numbers matter).
func _apply_modifiers(combined: WaveModifier) -> void:
	var tinted: Color = enemy_data.color
	if modifier_mask != 0:
		tinted = enemy_data.color.lerp(combined.color, 0.45)
	_body.modulate = tinted
	_body.scale = Vector2.ONE * enemy_data.visual_scale
	_health.max_health = combined.scaled_health(enemy_data.max_health)
	_base_damage_taken = combined.damage_taken_multiplier * enemy_data.damage_taken
	_health.damage_taken_multiplier = _base_damage_taken
	_speed = enemy_data.move_speed * combined.speed_multiplier
	_regen_per_second = combined.regen_per_second * enemy_data.heal_received


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
