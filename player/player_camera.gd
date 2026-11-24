class_name PlayerCamera
extends Camera2D
## Follows the player at whatever rate the screen refreshes (60, 144, 180 Hz...).
## The player moves 60 times a second and the engine draws it between those ticks
## (physics interpolation). This camera computes that same drawn position every frame,
## plus the prediction easing offset, and follows it, so the view and the player move
## together with no judder. A Camera2D left to the engine would only move on ticks.

## Further than this in one tick is a teleport (respawn): snap instead of blending.
const TELEPORT_DISTANCE: float = 100.0

## The node whose drawn position we follow (the player body).
@export var body: Node2D
## The player's visual offset (prediction easing) on top of the body.
@export var visual: Node2D
## Seconds to catch up with the player. 0 = locked to the player (no lag at all).
var follow_time: float = 0.0
## While our player is down: the teammate to watch (null = follow our own player).
var spectate_target: Node2D = null
## Seconds to catch up with a spectated teammate (smooths their network updates).
var spectate_follow_time: float = 0.15
## The world box every window shows (PlayerData.view_size, FairView).
var view_size: Vector2 = Vector2(1152, 648)
var view_max_crop: float = 0.0

## Screen shake tuning (looks only; `offset` moves the view, never the player).
var feedback: FeedbackData = FeedbackData.load_default()

var _previous_tick_position: Vector2 = Vector2.ZERO
var _current_tick_position: Vector2 = Vector2.ZERO
## Screen shake, 0..1; the offset grows with its square, so small shakes stay subtle.
var _shake: float = 0.0
var _shake_rng := RandomNumberGenerator.new()


## Places itself every frame from our own blend, so the engine must not blend it too.
## The scene sets physics_interpolation_mode = Off, top_level and process_callback = Idle:
## they must be in place before the camera enters the tree, or Godot (with physics
## interpolation on) forces it back to physics ticks, which is 60 Hz steps again.
func _ready() -> void:
	position_smoothing_enabled = false
	process_physics_priority = 50
	snap_to_body()
	EventBus.local_player_hurt.connect(_on_local_player_hurt.unbind(1))
	EventBus.blast_shown.connect(_on_blast_shown)


## Adds shake (0..1, capped at 1). Only the camera in use shows it.
func add_shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 1.0)


## The camera offset for `shake` (0..1) in direction `angle`.
static func shake_offset(shake: float, max_offset: float, angle: float) -> Vector2:
	return Vector2.from_angle(angle) * max_offset * shake * shake


func snap_to_body() -> void:
	_previous_tick_position = body.global_position
	_current_tick_position = body.global_position
	global_position = body.global_position


## After the player has moved this tick (priority 50 runs after it).
func _physics_process(_delta: float) -> void:
	_previous_tick_position = _current_tick_position
	_current_tick_position = body.global_position
	if _previous_tick_position.distance_to(_current_tick_position) > TELEPORT_DISTANCE:
		snap_to_body()


func _process(delta: float) -> void:
	zoom = Vector2.ONE * FairView.zoom_for(get_viewport_rect().size, view_size, view_max_crop)
	if spectate_target != null and is_instance_valid(spectate_target):
		var watched: Vector2 = spectate_target.global_position
		global_position = follow(global_position, watched, delta, spectate_follow_time)
	else:
		global_position = follow(global_position, drawn_position(), delta, follow_time)
	_shake = maxf(_shake - feedback.shake_decay * delta, 0.0)
	var angle: float = _shake_rng.randf() * TAU
	offset = shake_offset(_shake, feedback.shake_max_offset, angle)


func _on_local_player_hurt() -> void:
	add_shake(feedback.shake_on_hurt)


func _on_blast_shown(at: Vector2, radius: float) -> void:
	if is_current():
		add_shake(feedback.blast_shake(global_position.distance_to(at), radius))


## Where the engine draws the body this frame: between the last two ticks.
func drawn_position() -> Vector2:
	var fraction: float = Engine.get_physics_interpolation_fraction()
	var offset: Vector2 = visual.position if visual != null else Vector2.ZERO
	return _previous_tick_position.lerp(_current_tick_position, fraction) + offset


## Frame-rate independent follow: the same feel at any refresh rate.
static func follow(from: Vector2, to: Vector2, delta: float, catch_up_time: float) -> Vector2:
	if catch_up_time <= 0.0:
		return to
	return from.lerp(to, 1.0 - exp(-delta / catch_up_time))
