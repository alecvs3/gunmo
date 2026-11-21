class_name NetEntity
extends Node
## Makes its parent a replicated entity. Add it to any networked scene, set `kind`, and give
## the parent these methods:
##   capture_net_state() -> NetState         host: the parent's state right now
##   apply_net_state(state: NetState)         clients: show this (already interpolated) state
## For an entity a client predicts itself (its own player) or that only needs the newest state
## (the match), call use_latest_states() and implement
##   receive_authoritative_state(tick: int, state: NetState)
## The parent can be any Node; Node2D parents are hidden until their first state.
## The host gives each entity an id as it enters the tree; a spawn-only MultiplayerSynchronizer
## sends that id to clients with the spawn.

@export_enum("None:0", "Player:1", "Enemy:2", "Match:3") var kind: int = NetKinds.NONE
## Unique per session. Assigned by the host; synced once at spawn.
var net_id: int = 0
## Clients: false when the parent applies states itself instead of being interpolated.
var interpolate: bool = true

var buffer := StateBuffer.new()
var _has_state: bool = false

@onready var _entity: Node = get_parent()


func _enter_tree() -> void:
	if multiplayer.is_server() and net_id == 0:
		net_id = NetworkManager.replicator.allocate_id()


## On clients the parent stays hidden until its first state arrives, and is drawn by this
## node at render rate, so the engine's physics interpolation is turned off for it.
func _ready() -> void:
	NetworkManager.replicator.register(self)
	if multiplayer.is_server():
		set_process(false)
		return
	if _entity is CanvasItem:
		(_entity as CanvasItem).visible = false
	_entity.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _exit_tree() -> void:
	NetworkManager.replicator.unregister(self)


func _process(_delta: float) -> void:
	if not interpolate or buffer.is_empty():
		return
	_entity.apply_net_state(buffer.sample(NetworkManager.clock.render_tick()))


## Host: the parent's current state for the next snapshot.
func capture() -> NetState:
	return _entity.capture_net_state()


## Client: a state for this entity arrived in a snapshot.
func receive(tick: int, state: NetState) -> void:
	buffer.push(tick, state)
	if not interpolate:
		_entity.receive_authoritative_state(tick, state)
	elif not _has_state:
		_entity.apply_net_state(state)
	_has_state = true


## The parent gets every new state at once (receive_authoritative_state) instead of being
## interpolated, and drawing goes back to the engine's interpolation.
func use_latest_states() -> void:
	interpolate = false
	_entity.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
