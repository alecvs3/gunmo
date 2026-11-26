class_name ProjectileSystem
extends Node
## Spawns and tracks bullets on every peer.
##   Host: a real bullet for every EventBus.shot_fired, announced to every peer except the
##         shooter (who already shows its own); when it ends, everyone is told where and when.
##   Owner client: a predicted bullet for every EventBus.shot_predicted, shown at once.
##   Other clients: a remote bullet for every announcement.
## Every hit the host decides is confirmed to the shooter (EVENT_HIT), including hits a
## piercing bullet flies through, and the player who was hit is told which shot it was and where
## it came from (EVENT_HURT, for the hit-direction marker and hurt sound). A bot's or enemy's
## bullet that visibly reaches our own player plays that at once (Bullet.reached_us, with the
## mode's LatencyPolicy.predict_own_hurt on); the host's EVENT_HURT for it then plays nothing.
## An enemy's touch (EventBus.contact_hit) is told the same way, naming the enemy and the tick
## of the victim's own timeline it was judged on.
## Announcements are reliable NetChannel events, so no bullet is ever missed or left flying.
## Shots that explode (rockets) are detonated by the host where they land (Explosion), and
## every peer is shown the blast (EVENT_BLAST).

## Client: one of our own shots hit something (the host's verdict); for hit markers.
signal hit_confirmed(shot_key: String, at: Vector2)

## One scene per WeaponData.Projectile, in that order.
const PROJECTILE_SCENES: Array[PackedScene] = [
	preload("res://weapons/bullet.tscn"),
	preload("res://weapons/rocket.tscn"),
	preload("res://weapons/pellet.tscn"),
	preload("res://weapons/rifle_round.tscn"),
	preload("res://weapons/enemy_bolt.tscn"),
]
const EXPLOSION_SCENE: PackedScene = preload("res://weapons/explosion_flash.tscn")
## NetChannel event topic for bullets.
const TOPIC: int = 1
const EVENT_FIRED: int = 1
const EVENT_ENDED: int = 2
const EVENT_HIT: int = 3
const EVENT_HURT: int = 4
const EVENT_BLAST: int = 5
## What an EVENT_HURT is about.
const HURT_BULLET: int = 0
const HURT_CONTACT: int = 1

@export var projectiles_root: Node2D

var _bullets: Dictionary = {}
## Client: shot key -> seconds when its hurt was shown before the host's EVENT_HURT.
var _hurt_shown: Dictionary = {}


## EVENT_HURT: the victim is told what hit it and from where. A bullet (HURT_BULLET) names its
## shot; an enemy's touch (HURT_CONTACT) names the enemy (its shooter id) and, as `detail`, the
## tick of the victim's own timeline it was judged on (-1 = not judged on their view). `detail`
## travels as a u32 (shot ids are unsigned; a tick of -1 arrives as 0xFFFFFFFF).
static func encode_hurt(
	source: int, from_direction: Vector2, shooter_id: int, detail: int
) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(EVENT_HURT)
	buffer.put_u8(source)
	NetCodec.put_vector2(buffer, from_direction)
	buffer.put_32(shooter_id)
	buffer.put_u32(detail & 0xFFFFFFFF)
	return buffer.data_array


## Decodes an EVENT_HURT payload (after its kind byte) into [from_direction, shot key], or []
## if bad. The shot key is "" for an enemy's touch (it can't have been shown before).
static func decode_hurt(buffer: StreamPeerBuffer) -> Array:
	if buffer.get_available_bytes() < 17:
		return []
	var source: int = buffer.get_u8()
	var from_direction: Vector2 = NetCodec.get_vector2(buffer)
	var shooter_id: int = buffer.get_32()
	var detail: int = buffer.get_u32()
	if not from_direction.is_finite() or source not in [HURT_BULLET, HURT_CONTACT]:
		return []
	var key: String = "%d:%d" % [shooter_id, detail] if source == HURT_BULLET else ""
	return [from_direction.normalized(), key]


func _ready() -> void:
	if multiplayer.is_server():
		EventBus.shot_fired.connect(_on_shot_fired)
		EventBus.blast_requested.connect(_broadcast_blast)
		EventBus.contact_hit.connect(_on_contact_hit)
	else:
		EventBus.shot_predicted.connect(_spawn.bind(Bullet.Mode.PREDICTED))
		NetworkManager.channel.event_received.connect(_on_event_received)


func bullet_count() -> int:
	return _bullets.size()


func _on_shot_fired(shot: Shot) -> void:
	_spawn(shot, Bullet.Mode.AUTHORITATIVE)
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(EVENT_FIRED)
	shot.encode(buffer)
	for peer_id in multiplayer.get_peers():
		if peer_id != shot.shooter_id:
			NetworkManager.channel.send_event(peer_id, TOPIC, buffer.data_array)


func _spawn(shot: Shot, mode: Bullet.Mode) -> void:
	var kind: int = clampi(shot.projectile, 0, PROJECTILE_SCENES.size() - 1)
	var scene: PackedScene = PROJECTILE_SCENES[kind]
	var bullet: Bullet = scene.instantiate()
	bullet.setup(shot, mode)
	bullet.finished.connect(_on_bullet_finished)
	bullet.hit_landed.connect(_on_bullet_hit)
	if mode == Bullet.Mode.AUTHORITATIVE:
		bullet.hit_landed.connect(_on_bullet_hit_explode)
	elif mode == Bullet.Mode.PREDICTED:
		bullet.hit_predicted.connect(_on_hit_predicted)
	else:
		bullet.reached_us.connect(_on_reached_us)
	_bullets[shot.key()] = bullet
	projectiles_root.add_child(bullet)
	EventBus.shot_shown.emit(shot)


func _on_bullet_finished(
	bullet: Bullet, end_point: Vector2, hit_something: bool, end_tick: float
) -> void:
	_bullets.erase(bullet.shot.key())
	if bullet.mode != Bullet.Mode.AUTHORITATIVE:
		return
	if not hit_something:
		_explode(bullet.shot, end_point, null)
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(EVENT_ENDED)
	buffer.put_32(bullet.shot.shooter_id)
	buffer.put_u32(bullet.shot.shot_id)
	NetCodec.put_vector2(buffer, end_point)
	buffer.put_double(end_tick)
	buffer.put_u8(1 if hit_something else 0)
	for peer_id in multiplayer.get_peers():
		NetworkManager.channel.send_event(peer_id, TOPIC, buffer.data_array)


## Host: an exploding shot that hit someone blasts everyone else around them.
func _on_bullet_hit_explode(bullet: Bullet, at: Vector2, hitbox: HitboxComponent) -> void:
	_explode(bullet.shot, at, hitbox)


## Host: deal the blast (if the shot explodes) and show it here and on every client.
func _explode(shot: Shot, at: Vector2, direct_hit: HitboxComponent) -> void:
	var candidates: Array[HitboxComponent] = NetworkManager.lag_compensator.hitboxes()
	if Explosion.detonate(shot, at, direct_hit, candidates):
		_broadcast_blast(at, shot.blast_radius)


## Host: show a blast (a rocket's, or an enemy's: EventBus.blast_requested) here and on
## every client.
func _broadcast_blast(at: Vector2, radius: float) -> void:
	_show_blast(at, radius)
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(EVENT_BLAST)
	NetCodec.put_vector2(buffer, at)
	buffer.put_float(radius)
	for peer_id in multiplayer.get_peers():
		NetworkManager.channel.send_event(peer_id, TOPIC, buffer.data_array)


func _show_blast(at: Vector2, radius: float) -> void:
	if not at.is_finite() or not is_finite(radius) or radius <= 0.0:
		return
	var flash: ExplosionFlash = EXPLOSION_SCENE.instantiate()
	flash.position = at
	flash.radius = minf(radius, 1000.0)
	projectiles_root.add_child(flash)
	EventBus.blast_shown.emit(at, flash.radius)


## Host: tell the shooter its bullet hit (the host's own shots are confirmed locally), and
## the player it hit which way it came from.
func _on_bullet_hit(bullet: Bullet, at: Vector2, hitbox: HitboxComponent) -> void:
	var shot: Shot = bullet.shot
	_tell_victim(hitbox.owner_id, -shot.direction, HURT_BULLET, shot.shooter_id, shot.shot_id)
	var shooter_id: int = bullet.shot.shooter_id
	if shooter_id == multiplayer.get_unique_id():
		hit_confirmed.emit(bullet.shot.key(), at)
		return
	if shooter_id not in multiplayer.get_peers():
		return
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(EVENT_HIT)
	buffer.put_u32(bullet.shot.shot_id)
	NetCodec.put_vector2(buffer, at)
	NetworkManager.channel.send_event(shooter_id, TOPIC, buffer.data_array)


## Owner client: our own bullet landed on our screen. With the mode's latency policy on, its hit
## effects play now instead of when the host's health drop arrives (looks and sounds only).
## A shield's front we see it hit shows nothing (the host blocks it too).
func _on_hit_predicted(bullet: Bullet, at: Vector2, hitbox: HitboxComponent) -> void:
	if not NetworkManager.latency_policy.predict_hit_effects:
		return
	var enemy := hitbox.get_parent() as ChaserEnemy
	if enemy != null and enemy.blocks_as_drawn(bullet.shot.direction):
		return
	EventBus.hit_predicted.emit(bullet.shot, at, hitbox.get_parent())


## Host: an enemy's touch hit a player: tell them which way it came from.
func _on_contact_hit(enemy: Node2D, hitbox: Node) -> void:
	var victim := hitbox as HitboxComponent
	var chaser := enemy as ChaserEnemy
	if victim == null or chaser == null:
		return
	var from_direction: Vector2 = victim.center().direction_to(chaser.global_position)
	var judged: int = chaser.judged_tick(victim)
	_tell_victim(victim.owner_id, from_direction, HURT_CONTACT, chaser.shooter_id(), judged)


## `from_direction` points from the victim toward where the hit came from; `detail` is the
## shot id for a bullet, the judged tick for a touch (see encode_hurt).
func _tell_victim(
	victim_id: int, from_direction: Vector2, source: int, shooter_id: int, detail: int
) -> void:
	if victim_id == multiplayer.get_unique_id():
		EventBus.local_player_hurt.emit(from_direction)
	elif victim_id in multiplayer.get_peers():
		var payload: PackedByteArray = encode_hurt(source, from_direction, shooter_id, detail)
		NetworkManager.channel.send_event(victim_id, TOPIC, payload)


## Client: a bot's or enemy's bullet visibly reached our own player: hurt now, not when the
## host's verdict arrives one round trip later.
func _on_reached_us(bullet: Bullet) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	_forget_old_hurts(now, NetworkManager.latency_policy.predicted_hit_seconds)
	_hurt_shown[bullet.shot.key()] = now
	EventBus.local_player_hurt.emit(-bullet.shot.direction)


## A shown hurt the host never confirmed in time was a misprediction (its sound already played).
func _forget_old_hurts(now: float, window: float) -> void:
	for key: String in _hurt_shown.keys():
		if now - float(_hurt_shown[key]) > window:
			_hurt_shown.erase(key)


## Client: the host says a shot hurt us. Shown already (it visibly reached us) = nothing more.
func _on_hurt(hurt: Array) -> void:
	if hurt.is_empty():
		return
	if not hurt[1].is_empty() and _hurt_shown.has(hurt[1]):
		_hurt_shown.erase(hurt[1])
		return
	EventBus.local_player_hurt.emit(hurt[0])


func _on_event_received(topic: int, data: PackedByteArray) -> void:
	if topic != TOPIC or data.is_empty():
		return
	var buffer: StreamPeerBuffer = NetCodec.buffer_from(data)
	match buffer.get_u8():
		EVENT_FIRED:
			_spawn(Shot.decode(buffer), Bullet.Mode.REMOTE)
		EVENT_ENDED:
			_on_shot_ended(buffer)
		EVENT_HIT:
			var key: String = "%d:%d" % [multiplayer.get_unique_id(), buffer.get_u32()]
			hit_confirmed.emit(key, NetCodec.get_vector2(buffer))
		EVENT_BLAST:
			var at: Vector2 = NetCodec.get_vector2(buffer)
			_show_blast(at, buffer.get_float())
		EVENT_HURT:
			_on_hurt(decode_hurt(buffer))


func _on_shot_ended(buffer: StreamPeerBuffer) -> void:
	var shooter_id: int = buffer.get_32()
	var key: String = "%d:%d" % [shooter_id, buffer.get_u32()]
	var end_point: Vector2 = NetCodec.get_vector2(buffer)
	var end_tick: float = buffer.get_double()
	var hit_something: bool = buffer.get_u8() == 1
	var bullet: Bullet = _bullets.get(key)
	if bullet != null:
		bullet.end_at(end_point, end_tick, hit_something)
