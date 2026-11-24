class_name PlayerSpectate
extends Node
## Owner only: while our player is down, the camera follows a living teammate. Clicking (fire)
## switches to the next one. Tells the HUD who we are watching (EventBus.spectating_changed).

@export var player: Player
@export var camera: PlayerCamera

var _target: Player = null


## The teammate to watch after `current` (0 = none yet), in a stable order; 0 if nobody is
## alive.
static func next_peer(living_peer_ids: Array[int], current: int) -> int:
	if living_peer_ids.is_empty():
		return 0
	var sorted_ids: Array[int] = living_peer_ids.duplicate()
	sorted_ids.sort()
	var index: int = sorted_ids.find(current)
	return sorted_ids[(index + 1) % sorted_ids.size()]


func _process(_delta: float) -> void:
	if player.is_alive or player.is_downed():
		if _target != null:
			_watch(null)
		return
	if _target == null or not is_instance_valid(_target) or not _target.is_alive:
		_watch(_next_after(0))


func _unhandled_input(event: InputEvent) -> void:
	if not player.is_alive and not player.is_downed() and event.is_action_pressed("fire"):
		_watch(_next_after(_target.peer_id if _target != null else 0))


func _next_after(current_peer: int) -> Player:
	var living: Dictionary = {}
	for node in get_tree().get_nodes_in_group(Groups.PLAYERS):
		var teammate := node as Player
		if teammate != null and teammate != player and teammate.is_alive:
			living[teammate.peer_id] = teammate
	var ids: Array[int] = []
	ids.assign(living.keys())
	return living.get(next_peer(ids, current_peer))


func _watch(target: Player) -> void:
	_target = target
	camera.spectate_target = target
	EventBus.spectating_changed.emit(target.peer_id if target != null else 0)
