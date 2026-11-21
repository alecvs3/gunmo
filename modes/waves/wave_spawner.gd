class_name WaveSpawner
extends Node
## Host: releases a wave's enemies into the level one at a time, at the schedule's pace,
## never more than max_alive at once, at spawn points away from the living players.

const CHASER_SCENE: PackedScene = preload("res://enemies/chaser.tscn")

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
	_spawn(_queue.pop_front())


func _spawn(data: EnemyData) -> void:
	var enemy: ChaserEnemy = CHASER_SCENE.instantiate()
	enemy.enemy_data = data
	enemy.modifier_mask = _modifier_mask
	var player_positions: Array[Vector2] = []
	for player in _level.players():
		if player.is_alive:
			player_positions.append(player.global_position)
	enemy.position = pick_spawn_position(
		_level.enemy_spawn_positions(), player_positions, _schedule.min_spawn_distance, _rng
	)
	_level.add_enemy(enemy)
