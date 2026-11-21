class_name ProjectileSystem
extends Node
## Spawns and tracks bullets on every peer.
##   Host: a real bullet for every EventBus.shot_fired, announced to every peer except the
##         shooter (who already shows its own); when it ends, everyone is told where and when.
##   Owner client: a predicted bullet for every EventBus.shot_predicted, shown at once.
##   Other clients: a remote bullet for every announcement.
## Every hit the host decides is confirmed to the shooter (EVENT_HIT), including hits a
## piercing bullet flies through, and the player who was hit is told where it came from
## (EVENT_HURT, for the hit-direction marker).
## Announcements are reliable NetChannel events, so no bullet is ever missed or left flying.
## The host also resolves the bullets' HitEffects (ImpactEffects) and shows every peer the
## arcs and blasts (EVENT_FLASH).

## Client: one of our own shots hit something (the host's verdict); for hit markers.
signal hit_confirmed(shot_key: String, at: Vector2)

const BULLET_SCENE: PackedScene = preload("res://weapons/bullet.tscn")
## NetChannel event topic for bullets.
const TOPIC: int = 1
const EVENT_FIRED: int = 1
const EVENT_ENDED: int = 2
const EVENT_HIT: int = 3
const EVENT_HURT: int = 4
const EVENT_FLASH: int = 5

@export var projectiles_root: Node2D

var _bullets: Dictionary = {}


func _ready() -> void:
	if multiplayer.is_server():
		EventBus.shot_fired.connect(_on_shot_fired)
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
	var bullet: Bullet = BULLET_SCENE.instantiate()
	bullet.setup(shot, mode)
	bullet.finished.connect(_on_bullet_finished)
	bullet.hit_landed.connect(_on_bullet_hit)
	if mode == Bullet.Mode.AUTHORITATIVE:
		bullet.hit_landed.connect(_on_impact)
	_bullets[shot.key()] = bullet
	projectiles_root.add_child(bullet)


func _on_bullet_finished(
	bullet: Bullet, end_point: Vector2, hit_something: bool, end_tick: float
) -> void:
	_bullets.erase(bullet.shot.key())
	if bullet.mode != Bullet.Mode.AUTHORITATIVE:
		return
	if not hit_something:
		_show_flashes(ImpactEffects.on_stop(bullet.shot, end_point, _hitboxes()))
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(EVENT_ENDED)
	buffer.put_32(bullet.shot.shooter_id)
	buffer.put_u32(bullet.shot.shot_id)
	NetCodec.put_vector2(buffer, end_point)
	buffer.put_double(end_tick)
	buffer.put_u8(1 if hit_something else 0)
	for peer_id in multiplayer.get_peers():
		NetworkManager.channel.send_event(peer_id, TOPIC, buffer.data_array)


## Host: tell the shooter its bullet hit (the host's own shots are confirmed locally), and
## the player it hit which way it came from.
func _on_bullet_hit(bullet: Bullet, at: Vector2, hitbox: HitboxComponent) -> void:
	_tell_victim(hitbox.owner_id, -bullet.shot.direction)
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


## Host: the bullet's effects on what it hit and around it.
func _on_impact(bullet: Bullet, at: Vector2, hitbox: HitboxComponent) -> void:
	_show_flashes(ImpactEffects.on_hit(bullet.shot, hitbox, at, _hitboxes()))


func _hitboxes() -> Array[HitboxComponent]:
	return NetworkManager.lag_compensator.hitboxes()


## Host: draw the arcs and blasts here and on every client.
func _show_flashes(flashes: Array[ImpactEffects.Flash]) -> void:
	for flash in flashes:
		_spawn_flash(flash.kind, flash.from, flash.to)
		var buffer := StreamPeerBuffer.new()
		buffer.put_u8(EVENT_FLASH)
		buffer.put_u8(flash.kind)
		NetCodec.put_vector2(buffer, flash.from)
		NetCodec.put_vector2(buffer, flash.to)
		for peer_id in multiplayer.get_peers():
			NetworkManager.channel.send_event(peer_id, TOPIC, buffer.data_array)


func _spawn_flash(kind: int, from: Vector2, to: Vector2) -> void:
	if not (from.is_finite() and to.is_finite()):
		return
	var flash := EffectFlash.new()
	flash.setup(kind, from, to)
	projectiles_root.add_child(flash)


## `from_direction` points from the victim toward where the bullet came from.
func _tell_victim(victim_id: int, from_direction: Vector2) -> void:
	if victim_id == multiplayer.get_unique_id():
		EventBus.local_player_hurt.emit(from_direction)
	elif victim_id in multiplayer.get_peers():
		var buffer := StreamPeerBuffer.new()
		buffer.put_u8(EVENT_HURT)
		NetCodec.put_vector2(buffer, from_direction)
		NetworkManager.channel.send_event(victim_id, TOPIC, buffer.data_array)


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
		EVENT_HURT:
			var from_direction: Vector2 = NetCodec.get_vector2(buffer)
			if from_direction.is_finite():
				EventBus.local_player_hurt.emit(from_direction.normalized())
		EVENT_FLASH:
			var kind: int = buffer.get_u8()
			var from: Vector2 = NetCodec.get_vector2(buffer)
			_spawn_flash(kind, from, NetCodec.get_vector2(buffer))


func _on_shot_ended(buffer: StreamPeerBuffer) -> void:
	var shooter_id: int = buffer.get_32()
	var key: String = "%d:%d" % [shooter_id, buffer.get_u32()]
	var end_point: Vector2 = NetCodec.get_vector2(buffer)
	var end_tick: float = buffer.get_double()
	var hit_something: bool = buffer.get_u8() == 1
	var bullet: Bullet = _bullets.get(key)
	if bullet != null:
		bullet.end_at(end_point, end_tick, hit_something)
