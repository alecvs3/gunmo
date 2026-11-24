class_name FeedbackSystem
extends Node
## The level's "game feel" effects, on every peer. Looks only.
## - Damage numbers: any HitFeedback asks through EventBus.damage_seen.
## - Death bursts: the host sees EventBus.enemy_killed, shows the burst and tells every client
##   where (EVENT_DEATH). Clients never guess from an enemy disappearing, because a match reset
##   removes enemies too.

## NetChannel event topic (ProjectileSystem uses 1).
const TOPIC: int = 2
const EVENT_DEATH: int = 1
## A burst bigger than this is a bad packet, not an enemy.
const MAX_BURST_SCALE: float = 10.0

## Where numbers and bursts are added (world space, above the floor).
@export var effects_root: Node2D
@export var data: FeedbackData
@export var sounds: SoundData

var _sound := SoundPlayback.new()


static func encode_death(at: Vector2, color: Color, size_scale: float) -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(EVENT_DEATH)
	NetCodec.put_vector2(buffer, at)
	buffer.put_u32(color.to_rgba32())
	buffer.put_float(size_scale)
	return buffer.data_array


## Decodes an EVENT_DEATH payload (after its kind byte) into [at, color, scale], or [] if bad.
static func decode_death(buffer: StreamPeerBuffer) -> Array:
	if buffer.get_available_bytes() < 16:
		return []
	var at: Vector2 = NetCodec.get_vector2(buffer)
	var color := Color.hex(buffer.get_u32())
	var size_scale: float = buffer.get_float()
	if not at.is_finite() or not is_finite(size_scale) or size_scale <= 0.0:
		return []
	return [at, color, minf(size_scale, MAX_BURST_SCALE)]


func _ready() -> void:
	if data == null:
		data = FeedbackData.load_default()
	if sounds == null:
		sounds = SoundData.load_default()
	add_child(_sound)
	EventBus.damage_seen.connect(_show_number)
	EventBus.blast_shown.connect(_on_blast_shown)
	EventBus.local_player_hurt.connect(_on_local_player_hurt.unbind(1))
	if multiplayer.is_server():
		EventBus.enemy_killed.connect(_on_enemy_killed)
	else:
		NetworkManager.channel.event_received.connect(_on_event_received)


func _show_number(at: Vector2, amount: int, big: bool) -> void:
	var number := DamageNumber.new()
	number.data = data
	number.amount = amount
	number.big = big
	number.position = at + Vector2(randf_range(-1.0, 1.0) * data.number_spread, -16.0)
	effects_root.add_child(number)
	_sound.play_at(sounds.enemy_big_hit if big else sounds.enemy_hit, at)


func _show_burst(at: Vector2, color: Color, size_scale: float) -> void:
	var burst := DeathBurst.new()
	burst.data = data
	burst.color = color
	burst.size_scale = size_scale
	burst.position = at
	effects_root.add_child(burst)
	_sound.play_at(sounds.enemy_death, at)


func _on_blast_shown(at: Vector2, _radius: float) -> void:
	_sound.play_at(sounds.blast, at)


func _on_local_player_hurt() -> void:
	_sound.play(sounds.player_hurt)


## Host: show it here and tell every client.
func _on_enemy_killed(enemy: Node2D, _killer_peer_id: int) -> void:
	var dying := enemy as ChaserEnemy
	if dying == null:
		return
	var at: Vector2 = dying.drawn_position()
	_show_burst(at, dying.burst_color(), dying.enemy_data.body_scale)
	var payload: PackedByteArray = encode_death(
		at, dying.burst_color(), dying.enemy_data.body_scale
	)
	for peer_id in multiplayer.get_peers():
		NetworkManager.channel.send_event(peer_id, TOPIC, payload)


func _on_event_received(topic: int, payload: PackedByteArray) -> void:
	if topic != TOPIC or payload.is_empty():
		return
	var buffer: StreamPeerBuffer = NetCodec.buffer_from(payload)
	if buffer.get_u8() != EVENT_DEATH:
		return
	var death: Array = decode_death(buffer)
	if not death.is_empty():
		_show_burst(death[0], death[1], death[2])
