class_name NetSimulator
extends RefCounted
## Fake latency, jitter and packet loss for our own gameplay packets, so prediction and
## interpolation can be tested on one PC. NetChannel runs every packet through it when active.

var latency_ms: int = 0
var jitter_ms: int = 0
## Share (0..1) of droppable packets thrown away.
var loss: float = 0.0

var _rng := RandomNumberGenerator.new()
## Pending packets, sorted by release time: [{"release": int, "payload": Variant}].
var _queue: Array[Dictionary] = []


func configure(latency: int, jitter: int, loss_share: float) -> void:
	latency_ms = maxi(latency, 0)
	jitter_ms = maxi(jitter, 0)
	loss = clampf(loss_share, 0.0, 1.0)


func set_seed(value: int) -> void:
	_rng.seed = value


func is_active() -> bool:
	return latency_ms > 0 or jitter_ms > 0 or loss > 0.0


## Queues a packet to be released later (or drops it, if droppable and unlucky).
func push(now_ms: int, payload: Variant, droppable: bool) -> void:
	if droppable and _rng.randf() < loss:
		return
	var delay: int = latency_ms + _rng.randi_range(-jitter_ms, jitter_ms)
	var entry: Dictionary = {"release": now_ms + maxi(delay, 0), "payload": payload}
	var index: int = _queue.size()
	while index > 0 and _queue[index - 1]["release"] > entry["release"]:
		index -= 1
	_queue.insert(index, entry)


## Every payload whose time has come, in release order.
func pop_ready(now_ms: int) -> Array:
	var ready: Array = []
	while not _queue.is_empty() and _queue[0]["release"] <= now_ms:
		ready.append(_queue.pop_front()["payload"])
	return ready


func clear() -> void:
	_queue.clear()
