class_name RateLimiter
extends RefCounted
## Host: how often each client may send something. Every peer has a bucket of `burst` tokens
## that refills at `per_second`; each message takes one, and a message with none left is
## dropped. Normal play never runs dry, a flooding client loses only its own extra messages.
## Pure, so it is unit-tested.

var per_second: float = 1.0
var burst: float = 1.0
## Messages dropped since the start, all peers together.
var dropped: int = 0

var _tokens: Dictionary[int, float] = {}
var _refilled_at: Dictionary[int, float] = {}


func _init(rate_per_second: float = 1.0, burst_size: float = 1.0) -> void:
	per_second = maxf(rate_per_second, 0.0)
	burst = maxf(burst_size, 1.0)


## True if `peer_id` may send one more message at `now` (seconds); takes a token if so.
func allow(peer_id: int, now: float) -> bool:
	var tokens: float = _tokens.get(peer_id, burst)
	var since: float = maxf(now - _refilled_at.get(peer_id, now), 0.0)
	tokens = minf(tokens + since * per_second, burst)
	_refilled_at[peer_id] = now
	if tokens < 1.0:
		_tokens[peer_id] = tokens
		dropped += 1
		return false
	_tokens[peer_id] = tokens - 1.0
	return true


## The peer left: a new peer with the same id starts with a full bucket.
func forget(peer_id: int) -> void:
	_tokens.erase(peer_id)
	_refilled_at.erase(peer_id)
