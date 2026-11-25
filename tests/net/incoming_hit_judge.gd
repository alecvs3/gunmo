extends RefCounted
## Client side of smoke scenarios H and I: judges every bot or enemy bullet that hit us.
##   fair     the host's end point was on our player at the tick it was judged on (fair dodging)
##   visible  the bullet as WE DREW IT was on our player at that tick (no hit from a bullet we
##            saw behind us). Judged only for bullets we had drawn by then: a point-blank shot
##            can hit before its EVENT_FIRED even reaches us (one-way latency), and no drawing
##            can show that; those are counted apart (never_drawn)
##   hurt_feedback_ms  from the bullet first drawn on us to our hurt sound: the moment it
##            reached us on our screen (Bullet.reached_us) or, without that, when the host's
##            EVENT_HURT arrived
## Positions are by tick of our own timeline (what our inputs are stamped with): the scene
## script records our player's, this records the drawn bullets'. It names no project classes
## (smoke scripts run before the autoloads exist).

## Bullet.Mode.REMOTE.
const REMOTE: int = 2
## Shot.ENEMY_SHOOTER_BASE: enemy shooter ids are at or below it (bots' are above, negative).
const ENEMY_SHOOTER_BASE: int = -(1 << 20)
## Player hitbox radius + bullet radius + a little slack for blending between ticks (px).
const ON_PLAYER_DISTANCE: float = 33.0

var bot_fair: int = 0
var bot_unfair: int = 0
var enemy_fair: int = 0
var enemy_unfair: int = 0
var visible: int = 0
var hidden: int = 0
## Hits whose bullet we had not drawn at all by the judged tick (its EVENT_FIRED came too late).
var never_drawn: int = 0

## Tick -> our player's hitbox centre, and tick -> usec it was recorded (the scene script's).
var _own_positions: Dictionary
var _tick_usec: Dictionary
## (name: String, value: float): stores one measurement (the smoke script's _add).
var _add: Callable
## Shot key -> {tick: where we drew it}.
var _drawn: Dictionary = {}
## Shot key -> usec our hurt sound played for it.
var _hurt_usec: Dictionary = {}
## Shot key -> usec it reached us on our screen (before the host's EVENT_HURT).
var _reached_usec: Dictionary = {}


func _init(own_positions: Dictionary, tick_usec: Dictionary, add: Callable) -> void:
	_own_positions = own_positions
	_tick_usec = tick_usec
	_add = add


func watch(projectiles: Node) -> void:
	projectiles.child_entered_tree.connect(_on_projectile)


## Every physics frame: where we draw each remote bullet at our own `tick`.
func record(tick: int, projectiles: Node) -> void:
	for bullet: Node in projectiles.get_children():
		if bullet.get("mode") != REMOTE or not (bullet as Node2D).visible:
			continue
		var key: String = bullet.get("shot").call("key")
		var track: Dictionary = _drawn.get(key, {})
		track[tick] = (bullet as Node2D).global_position
		_drawn[key] = track


## EVENT_HURT, after its kind byte: the host says shot `key` hurt us.
func on_hurt(buffer: StreamPeerBuffer) -> void:
	buffer.get_float()
	buffer.get_float()
	var key: String = "%d:%d" % [buffer.get_32(), buffer.get_u32()]
	_hurt_usec[key] = _reached_usec.get(key, Time.get_ticks_usec())


## EVENT_ENDED, after its kind byte: judge it if it was a bot's or enemy's shot that hurt us.
func on_ended(buffer: StreamPeerBuffer) -> void:
	var shooter_id: int = buffer.get_32()
	var key: String = "%d:%d" % [shooter_id, buffer.get_u32()]
	var end_point := Vector2(buffer.get_float(), buffer.get_float())
	var tick: int = roundi(buffer.get_double())
	var hit_something: bool = buffer.get_u8() == 1
	if not _hurt_usec.has(key) or not hit_something or shooter_id >= 0:
		return
	var hurt_usec: int = _hurt_usec[key]
	_hurt_usec.erase(key)
	if not _own_positions.has(tick):
		return
	_judge_fair(shooter_id, _on_player(end_point, tick))
	var track: Dictionary = _drawn.get(key, {})
	if track.keys().filter(func(t: int) -> bool: return t <= tick).is_empty():
		never_drawn += 1
	elif track.has(tick) and _on_player(track[tick], tick):
		visible += 1
	else:
		hidden += 1
	var first: int = _first_touch(track)
	if first >= 0 and _tick_usec.has(first):
		_add.call("hurt_feedback_ms", (hurt_usec - int(_tick_usec[first])) / 1000.0)


func bot_hits() -> int:
	return bot_fair + bot_unfair


func enemy_hits() -> int:
	return enemy_fair + enemy_unfair


func bullet_hits() -> int:
	return visible + hidden + never_drawn


static func share(good: int, bad: int) -> float:
	return good / float(good + bad) if good + bad > 0 else 0.0


func _on_projectile(node: Node) -> void:
	if node.get("mode") == REMOTE and node.has_signal("reached_us"):
		node.connect("reached_us", _on_reached_us)


func _on_reached_us(bullet: Node) -> void:
	_reached_usec[bullet.get("shot").call("key")] = Time.get_ticks_usec()


func _judge_fair(shooter_id: int, fair: bool) -> void:
	if shooter_id <= ENEMY_SHOOTER_BASE:
		enemy_fair += 1 if fair else 0
		enemy_unfair += 0 if fair else 1
	else:
		bot_fair += 1 if fair else 0
		bot_unfair += 0 if fair else 1


func _on_player(point: Vector2, tick: int) -> bool:
	return (_own_positions[tick] as Vector2).distance_to(point) <= ON_PLAYER_DISTANCE


## The first tick a bullet was drawn on our player (-1 = never).
func _first_touch(track: Dictionary) -> int:
	var ticks: Array = track.keys()
	ticks.sort()
	for tick: int in ticks:
		if _own_positions.has(tick) and _on_player(track[tick], tick):
			return tick
	return -1
