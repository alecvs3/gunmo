extends GutTest
## Safety net for every replicated state (every NetKinds kind): each field is filled with a
## value different from its default, then it must survive encode -> decode and copy(), and
## encode must write exactly byte_size() bytes. Adding a field but forgetting it in encode,
## decode, copy or SIZE fails here instead of causing a silent desync.
## Values are chosen to be exact in every wire format we use (u8 and up, f32): small positive
## integers and multiples of 0.25.

## Fields that are deliberately not sent (none yet). "Class.field".
const LOCAL_ONLY: Array[String] = []
## Fields the public form (for peers who only watch the entity) leaves out on purpose.
const NOT_PUBLIC: Array[String] = [
	"PlayerNetState.move_velocity",
	"PlayerNetState.knockback",
	"PlayerNetState.ammo",
	"PlayerNetState.cooldown_left",
	"PlayerNetState.reload_left",
	"PlayerNetState.last_command",
	"PlayerNetState.credits",
	"PlayerNetState.upgrade_levels",
]
const KINDS: Array[int] = [NetKinds.PLAYER, NetKinds.ENEMY, NetKinds.MATCH]
## Integer fields packed into fewer bits: "Class.field" -> how many values fit.
const NARROW: Dictionary = {"EnemyNetState.status": 4, "EnemyNetState.telegraph": 64}

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 12345


func test_every_kind_has_a_state() -> void:
	for kind in KINDS:
		assert_not_null(NetKinds.make_state(kind), "kind %d" % kind)


func test_every_field_survives_encode_and_decode() -> void:
	for kind in KINDS:
		var state: NetState = NetKinds.make_state(kind)
		var fields: Array[String] = _fill(state)
		var buffer := StreamPeerBuffer.new()
		state.encode(buffer)
		var label: String = _class_name(state)
		assert_eq(buffer.data_array.size(), state.byte_size(), "%s: byte_size" % label)
		var back: NetState = NetKinds.make_state(kind)
		back.decode(NetCodec.buffer_from(buffer.data_array))
		for field in fields:
			assert_eq(back.get(field), state.get(field), "%s.%s round trip" % [label, field])


func test_every_field_survives_copy() -> void:
	for kind in KINDS:
		var state: NetState = NetKinds.make_state(kind)
		if not state.has_method("copy"):
			continue
		var fields: Array[String] = _fill(state)
		var duplicate: NetState = state.call("copy")
		for field in fields:
			assert_eq(
				duplicate.get(field), state.get(field), "%s.%s copy" % [_class_name(state), field]
			)


## Sets every script field to a non-default value; returns the field names.
func _fill(state: NetState) -> Array[String]:
	var fields: Array[String] = []
	for property in state.get_property_list():
		if not property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		var field: String = property["name"]
		if "%s.%s" % [_class_name(state), field] in LOCAL_ONLY:
			continue
		var value: Variant = _value_unlike(state.get(field))
		var label: String = "%s.%s" % [_class_name(state), field]
		if NARROW.has(label):
			value = 1 + int(value) % (NARROW[label] - 1)
		assert_ne(
			value, state.get(field), "%s.%s got a different value" % [_class_name(state), field]
		)
		state.set(field, value)
		fields.append(field)
	return fields


func _value_unlike(current: Variant) -> Variant:
	match typeof(current):
		TYPE_BOOL:
			return not current
		TYPE_INT:
			return (current + _rng.randi_range(1, 120)) % 200 if current >= 0 else 7
		TYPE_FLOAT:
			return current + _rng.randi_range(1, 400) * 0.25
		TYPE_VECTOR2:
			return current + Vector2(_rng.randi_range(1, 400), -_rng.randi_range(1, 400)) * 0.25
		TYPE_PACKED_BYTE_ARRAY:
			var bytes: PackedByteArray = (current as PackedByteArray).duplicate()
			for i in bytes.size():
				bytes[i] = _rng.randi_range(1, 200)
			return bytes
	fail_test("no test value for type %d" % typeof(current))
	return current


func _class_name(state: NetState) -> String:
	return (state.get_script() as Script).get_global_name()


func test_public_form_keeps_every_field_others_need() -> void:
	for kind in KINDS:
		var state: NetState = NetKinds.make_state(kind)
		var fields: Array[String] = _fill(state)
		var buffer := StreamPeerBuffer.new()
		state.encode_public(buffer)
		var label: String = _class_name(state)
		assert_eq(buffer.data_array.size(), state.public_byte_size(), "%s: public size" % label)
		var back: NetState = NetKinds.make_state(kind)
		back.decode_public(NetCodec.buffer_from(buffer.data_array))
		for field in fields:
			if "%s.%s" % [label, field] in NOT_PUBLIC:
				continue
			assert_eq(back.get(field), state.get(field), "%s.%s public form" % [label, field])
