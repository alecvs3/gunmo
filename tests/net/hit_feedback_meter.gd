extends RefCounted
## Client side of smoke scenarios H and I: how long our own hits take to show.
## A PREDICTED bullet (our own copy) that stops on a target counts as a predicted hit on that
## target (skipped when two targets are close enough to be the one). Its feedback is the first
## drop of that target's health on our screen, which is what HitFeedback reacts to today (hit
## sound, flash, damage number). The scenarios make every test hit deal exactly 1 damage, so a
## drop of N answers the N oldest predicted hits on that target. Also counts how many predicted
## hits the host confirmed (EVENT_HIT).
## It names no project classes (smoke scripts run before the autoloads exist).

## Bullet.Mode.PREDICTED.
const PREDICTED: int = 1
## A predicted hit belongs to the target whose hitbox centre is this close (px).
const MATCH_DISTANCE: float = 48.0
## A predicted hit with no health drop after this long counts as unanswered.
const EXPIRE_USEC: int = 1_000_000

## Predicted hits whose target's health never dropped within EXPIRE_USEC.
var unanswered: int = 0
## Predicted hits skipped because two targets were close enough to be the one hit.
var ambiguous: int = 0

## () -> Array[Node]: the targets whose health we watch.
var _targets: Callable
## (name: String, value: float): stores one measurement (the smoke script's _add).
var _add: Callable
## Target instance id -> Array of usec times of predicted hits not answered yet.
var _pending: Dictionary = {}
## Target instance id -> its health last frame.
var _last_health: Dictionary = {}
var _predicted_keys: Array[String] = []
var _confirmed: Dictionary = {}


func _init(targets: Callable, add: Callable) -> void:
	_targets = targets
	_add = add


## Starts watching our own bullets (spawned under `projectiles`) and the host's confirmations.
func watch(projectiles: Node, projectile_system: Node) -> void:
	projectiles.child_entered_tree.connect(_on_projectile)
	projectile_system.connect("hit_confirmed", _on_hit_confirmed)


## Call every rendered frame: compares each target's health with last frame.
func poll() -> void:
	var now: int = Time.get_ticks_usec()
	for target: Node in _targets.call():
		var id: int = target.get_instance_id()
		var health: int = target.get_node("HealthComponent").current_health
		var dropped: int = int(_last_health.get(id, health)) - health
		_last_health[id] = health
		if dropped > 0:
			_answer(id, dropped, now)
	_expire(now)


func predicted_hits() -> int:
	return _predicted_keys.size()


func confirm_share() -> float:
	if _predicted_keys.is_empty():
		return 0.0
	var confirmed: int = 0
	for key in _predicted_keys:
		confirmed += 1 if _confirmed.has(key) else 0
	return confirmed / float(_predicted_keys.size())


func _on_projectile(node: Node) -> void:
	if node.get("mode") == PREDICTED and node.has_signal("finished"):
		node.connect("finished", _on_predicted_finished)


func _on_predicted_finished(
	bullet: Node, end_point: Vector2, hit_something: bool, _end_tick: float
) -> void:
	if not hit_something:
		return
	var target: Node = _nearest_target(end_point)
	if target == null:
		return
	var id: int = target.get_instance_id()
	var times: Array = _pending.get(id, [])
	times.append(Time.get_ticks_usec())
	_pending[id] = times
	_predicted_keys.append(bullet.get("shot").call("key"))


func _on_hit_confirmed(shot_key: String, _at: Vector2) -> void:
	_confirmed[shot_key] = true


## The one target whose hitbox centre is within MATCH_DISTANCE of `point`; null when none is,
## or when two are (we can't tell which one the bullet stopped on).
func _nearest_target(point: Vector2) -> Node:
	var found: Node = null
	for target: Node in _targets.call():
		var center: Vector2 = target.get_node("HitboxComponent").call("center")
		if center.distance_to(point) > MATCH_DISTANCE:
			continue
		if found != null:
			ambiguous += 1
			return null
		found = target
	return found


func _answer(id: int, count: int, now: int) -> void:
	var times: Array = _pending.get(id, [])
	for i in mini(count, times.size()):
		_add.call("hit_feedback_ms", (now - int(times.pop_front())) / 1000.0)


func _expire(now: int) -> void:
	for id: int in _pending:
		var times: Array = _pending[id]
		while not times.is_empty() and now - int(times[0]) > EXPIRE_USEC:
			times.pop_front()
			unanswered += 1
