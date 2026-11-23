class_name WaveSpawner
extends Node
## Host: releases a wave's enemies into the level one at a time (a group type, like swarmers,
## a whole group at once around one point), at the schedule's pace, never more than max_alive
## at once, at spawn points away from the living players.

const CHASER_SCENE: PackedScene = preload("res://enemies/chaser.tscn")
## Group members spawn on a ring this far around the group's point (px).
const GROUP_SPREAD: float = 26.0

var _level: Level
var _schedule: WaveSchedule
var _queue: Array[EnemyData] = []
var _interval: float = 1.0
var _time_left: float = 0.0
var _rng := RandomNumberGenerator.new()
var _modifier_mask: int = 0


## The spawn point to use: a random one at least min_distance from every player, or (when
## none is that far) the one furthest from its nearest player.
static func pick_spawn_position(
	points: Array[Vector2], players: Array[Vector2], min_distance: float, rng: RandomNumberGenerator
) -> Vector2:
	var far_enough: Array[Vector2] = []
	var best: Vector2 = points[0]
	var best_gap: float = -1.0
	for point in points:
		var gap: float = INF
		for player in players:
			gap = minf(gap, point.distance_to(player))
		if gap >= min_distance:
			far_enough.append(point)
		if gap > best_gap:
			best_gap = gap
			best = point
	if far_enough.is_empty():
		return best
	return far_enough[rng.randi_range(0, far_enough.size() - 1)]


## How many enemies at the front of `queue` spawn together: the first one's group (the same
## type in a row, at most its group_size), never more than `room`.
static func group_count(queue: Array[EnemyData], room: int) -> int:
	if queue.is_empty() or room <= 0:
		return 0
	var first: EnemyData = queue[0]
	var count: int = 1
	while count < mini(first.group_size, room) and count < queue.size() and queue[count] == first:
		count += 1
	return count


## Where member `index` of a group of `size` stands around `point`.
static func group_offset(index: int, size: int) -> Vector2:
	if index == 0 or size <= 1:
		return Vector2.ZERO
	return Vector2.RIGHT.rotated(TAU * index / (size - 1)) * GROUP_SPREAD


func _ready() -> void:
	set_physics_process(multiplayer.is_server())


## Plans the wave (the same seed gives the same enemies) and starts releasing it. Every enemy
## gets the wave's modifiers (ModifierCatalog bitmask).
func start_wave(
	level: Level, schedule: WaveSchedule, wave: int, seed_value: int, modifier_mask: int
) -> void:
	_level = level
	_modifier_mask = modifier_mask
	_schedule = schedule
	_rng.seed = seed_value
	_queue = WaveBudget.plan(schedule, wave, _rng)
	_interval = schedule.spawn_interval(wave)
	_time_left = 0.0


func stop() -> void:
	_queue.clear()


## Enemies of this wave not spawned yet.
func remaining() -> int:
	return _queue.size()


func is_finished() -> bool:
	return _queue.is_empty()


func _physics_process(delta: float) -> void:
	if _queue.is_empty() or _level == null:
		return
	_time_left -= delta
	if _time_left > 0.0 or _level.enemy_count() >= _schedule.max_alive:
		return
	_time_left = _interval
	var count: int = group_count(_queue, _schedule.max_alive - _level.enemy_count())
	var point: Vector2 = _pick_point()
	for index in count:
		_spawn(_queue.pop_front(), point + group_offset(index, count))


func _pick_point() -> Vector2:
	var player_positions: Array[Vector2] = []
	for player in _level.players():
		if player.is_alive:
			player_positions.append(player.global_position)
	return pick_spawn_position(
		_level.enemy_spawn_positions(), player_positions, _schedule.min_spawn_distance, _rng
	)


func _spawn(data: EnemyData, at: Vector2) -> void:
	var enemy: ChaserEnemy = CHASER_SCENE.instantiate()
	enemy.enemy_data = data
	enemy.modifier_mask = _modifier_mask
	enemy.position = at
	_level.add_enemy(enemy)
