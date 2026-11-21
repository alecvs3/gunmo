class_name DisplayDelay
extends Node
## Host only: draws its body host_view_delay_ticks in the past, the way the host's shots see
## it (NetClock.render_tick). A player whose inputs arrive unevenly would otherwise visibly
## stop and jump on the host's screen; a short delay hides that. Only the drawing moves:
## `visual` (a child of the body) is offset so it shows where the body was, while the body
## itself keeps its real, simulated position for physics, AI and hit tests.
## Players whose input is the host's own (and anything not on the host) are drawn live.

## The simulated node (its global position is recorded every tick).
@export var body: Node2D
## What is drawn for it (a child of `body`, normally at the body's origin).
@export var visual: Node2D
## Optional: also draw this node's rotation in the past, from the body's `aim` property.
@export var pivot: Node2D

## Set false for the host's own player (any time; the parent's _ready runs after this one's).
var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			_update_processing()

var _positions: Array[Vector2] = []
var _aims: Array[float] = []


## Of `history` (newest first, one entry per tick), the value `ticks_back` + `fraction`
## ticks before the newest, blended between whole ticks. Holds the oldest when it runs out.
static func sample(history: Array, ticks_back: float) -> Variant:
	if history.is_empty():
		return null
	var back: float = clampf(ticks_back, 0.0, history.size() - 1.0)
	var newer: int = floori(back)
	var older: int = mini(newer + 1, history.size() - 1)
	var weight: float = back - newer
	var from: Variant = history[newer]
	var to: Variant = history[older]
	if from is float:
		return lerp_angle(from, to, weight)
	return (from as Vector2).lerp(to, weight)


func _ready() -> void:
	process_physics_priority = 50
	_update_processing()


func _update_processing() -> void:
	var active: bool = multiplayer.is_server() and enabled
	set_physics_process(active)
	set_process(active)
	if not active:
		snap()


## A teleport (respawn): forget the past so the body doesn't slide across the map.
func snap() -> void:
	_positions.clear()
	_aims.clear()
	if visual != null:
		visual.position = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	var keep: int = NetworkManager.config.host_view_delay_ticks + 2
	_positions.push_front(body.global_position)
	if pivot != null:
		_aims.push_front(float(body.get("aim")))
	while _positions.size() > keep:
		_positions.pop_back()
	while _aims.size() > keep:
		_aims.pop_back()


## The body is drawn by the engine between the last two ticks (physics interpolation): at
## `fraction` of the way from the previous tick. Draw the same blend, delay ticks earlier.
func _process(_delta: float) -> void:
	if _positions.is_empty():
		return
	var delay: float = NetworkManager.config.host_view_delay_ticks
	var fraction: float = Engine.get_physics_interpolation_fraction()
	if not body.is_physics_interpolated_and_enabled():
		fraction = 1.0
	var drawn: Vector2 = sample(_positions, 1.0 - fraction)
	var wanted: Vector2 = sample(_positions, 1.0 - fraction + delay)
	visual.position = body.global_transform.basis_xform_inv(wanted - drawn)
	if pivot != null and not _aims.is_empty():
		pivot.rotation = sample(_aims, 1.0 - fraction + delay)
