class_name ChaserEnemy
extends CharacterBody2D
## Chases the nearest living player and damages and pushes away players it touches.
## One scene for every chaser type: the EnemyData decides speed, health, color and so on.
## The AI runs only on the host; clients show its snapshots, interpolated (NetEntity).

## Where clients may load enemy data from (the path arrives from the host at spawn).
const DATA_FOLDER: String = "res://enemies/data/"

## Set before the enemy enters the tree; its path is sent to clients with the spawn.
@export var enemy_data: EnemyData:
	set(value):
		enemy_data = value
		data_path = value.resource_path if value != null else ""

## Synced once at spawn, so clients play the same type.
var data_path: String = ""

var _contact_cooldown_left: float = 0.0

@onready var _health: HealthComponent = $HealthComponent
@onready var _knockback: KnockbackComponent = $KnockbackComponent
@onready var _contact_area: Area2D = $ContactArea


func _ready() -> void:
	if not multiplayer.is_server():
		_load_data_from_host()
	($Body as Polygon2D).color = enemy_data.color
	_health.max_health = enemy_data.max_health
	_knockback.configure(
		enemy_data.knockback_friction, enemy_data.knockback_bounce, enemy_data.knockback_taken
	)
	if not multiplayer.is_server():
		set_physics_process(false)
		_contact_area.monitoring = false
		return
	_health.reset()
	_health.died.connect(_on_died)
	EventBus.enemy_spawned.emit(self)


func _physics_process(delta: float) -> void:
	_move(delta)
	_deal_contact_damage(delta)


func capture_net_state() -> NetState:
	var state := EnemyNetState.new()
	state.position = position
	state.health = _health.current_health
	return state


func apply_net_state(state: NetState) -> void:
	var enemy_state := state as EnemyNetState
	position = enemy_state.position
	_health.apply_replicated(enemy_state.health)
	visible = true


func _move(delta: float) -> void:
	var target: Node2D = _find_nearest_target()
	var chase: Vector2 = Vector2.ZERO
	if target != null:
		chase = global_position.direction_to(target.global_position) * enemy_data.move_speed
	velocity = chase + _knockback.velocity
	move_and_slide()
	_knockback.bounce_off_collisions(self)
	_knockback.step(delta)


func _find_nearest_target() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance: float = INF
	for candidate: Node2D in get_tree().get_nodes_in_group(Groups.LIVING_PLAYERS):
		var distance: float = global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _deal_contact_damage(delta: float) -> void:
	_contact_cooldown_left = maxf(_contact_cooldown_left - delta, 0.0)
	if _contact_cooldown_left > 0.0:
		return
	for area in _contact_area.get_overlapping_areas():
		var hitbox := area as HitboxComponent
		if hitbox == null:
			continue
		var away: Vector2 = global_position.direction_to(hitbox.center())
		hitbox.hit(enemy_data.contact_damage, 0, away * enemy_data.contact_knockback)
		_contact_cooldown_left = enemy_data.contact_interval


func _on_died(killer_peer_id: int) -> void:
	EventBus.enemy_killed.emit(self, killer_peer_id)
	queue_free()


## Clients: the host told us which type this is; only enemy data files are accepted.
func _load_data_from_host() -> void:
	if not data_path.begins_with(DATA_FOLDER) or not ResourceLoader.exists(data_path):
		return
	var loaded := load(data_path) as EnemyData
	if loaded != null:
		enemy_data = loaded
