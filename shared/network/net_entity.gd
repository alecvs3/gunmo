class_name NetEntity
extends Node
## Makes its parent a replicated entity. Add it to any networked scene, set `kind`, and give
## the parent these methods:
##   capture_net_state() -> NetState         host: the parent's state right now
##   apply_net_state(state: NetState)         clients: show this (already interpolated) state
## Optional, for an entity a client predicts itself (its own player): set `interpolate` false
## and implement receive_authoritative_state(tick: int, state: NetState).
## The host gives each entity an id as it enters the tree; a spawn-only MultiplayerSynchronizer
## sends that id to clients with the spawn.

@export_enum("None:0", "Player:1", "Enemy:2") var kind: int = NetKinds.NONE
## Unique per session. Assigned by the host; synced once at spawn.
var net_id: int = 0
## Clients: false when the parent applies states itself instead of being interpolated.
var interpolate: bool = true

var buffer := StateBuffer.new()
var _has_state: bool = false

@onready var _entity: Node2D = get_parent()


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
	_entity.visible = false
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


## For an entity that predicts itself: hand drawing back to the engine's interpolation.
func use_prediction() -> void:
	interpolate = false
	_entity.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_INHERIT
