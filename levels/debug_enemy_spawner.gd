class_name DebugEnemySpawner
extends Node
## Test tool: spawns one enemy every `interval` seconds at a random spawn point. Host only.
## The level's EnemySpawner (MultiplayerSpawner) replicates each enemy to clients.

const ENEMY_SCENE: PackedScene = preload("res://enemies/test_enemy.tscn")

@export var interval: float = 3.0
@export var max_alive: int = 15
@export var enemies_root: Node2D
@export var spawn_points: Node2D

var _time_left: float = 0.0


func _ready() -> void:
	_time_left = interval
	set_physics_process(multiplayer.is_server())


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left = interval
	if enemies_root.get_child_count() < max_alive:
		_spawn_enemy()


func _spawn_enemy() -> void:
	var enemy: Node2D = ENEMY_SCENE.instantiate()
	var point: Node2D = spawn_points.get_children().pick_random()
	enemy.position = point.position
	enemies_root.add_child(enemy, true)
