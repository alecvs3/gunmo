extends GutTest
## Random bytes into everything the host reads from a client (input commands, the join hello,
## shop requests) and into the client's snapshot and hurt-event readers. Nothing may crash, read
## past the data, or let a non-finite or out-of-range value through. Seeded, so a failure
## repeats.

const ROUNDS: int = 3000
const SHOP_CATALOG: ShopCatalog = preload("res://upgrades/data/shop_catalog.tres")

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	_rng.seed = 20261123


func _random_bytes(size: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(size)
	for i in size:
		bytes[i] = _rng.randi_range(0, 255)
	return bytes


func test_garbage_commands_decode_to_nothing_or_to_safe_commands() -> void:
	var decoded: int = 0
	for i in ROUNDS:
		var data: PackedByteArray = _random_bytes(_rng.randi_range(0, 120))
		if i % 2 == 0:  # the right length for its count byte, so the decoder really reads it
			var count: int = _rng.randi_range(0, InputCommand.MAX_PER_PACKET + 2)
			data = _random_bytes(1 + count * InputCommand.ENCODED_SIZE)
			data[0] = count
		for command in InputCommand.decode_batch(data):
			decoded += 1
			_assert_safe(command.sanitized())
	assert_gt(decoded, 0, "some garbage had a valid shape and was decoded")


func _assert_safe(command: InputCommand) -> void:
	var ok: bool = (
		command.move.is_finite()
		and command.move.length() <= 1.0001
		and is_finite(command.aim)
		and absf(command.aim) <= PI + 0.0001
		and command.buttons & ~InputCommand.ALL_BUTTONS == 0
		and is_finite(command.view_tick)
		and is_finite(command.client_tick)
	)
	if not ok:
		fail_test("unsafe command got through: move %s aim %s" % [command.move, command.aim])


func test_oversized_command_packets_are_refused() -> void:
	var count: int = InputCommand.MAX_PER_PACKET + 1
	var data: PackedByteArray = _random_bytes(1 + count * InputCommand.ENCODED_SIZE)
	data[0] = count
	assert_eq(InputCommand.decode_batch(data).size(), 0)


func test_garbage_hellos_never_get_in() -> void:
	var host_hello: Dictionary = Handshake.make_hello("0.1.0", "abc123")
	for i in ROUNDS:
		var hello: Dictionary = Handshake.decode(_random_bytes(_rng.randi_range(0, 64)))
		assert_ne(Handshake.check_hello(hello, host_hello, 1, 8, true), "", "garbage was let in")


func test_real_hellos_and_replies_still_decode() -> void:
	var hello: Dictionary = Handshake.make_hello("0.1.0", "abc123", "Yusuf")
	assert_eq(Handshake.decode(Handshake.encode(hello)), hello)
	assert_eq(
		Handshake.decode(Handshake.encode(Handshake.reject("full"))), Handshake.reject("full")
	)


func test_huge_aim_becomes_zero_instead_of_garbage() -> void:
	var command := InputCommand.new()
	command.aim = 5.3e180
	assert_eq(command.sanitized().aim, 0.0)
	command.aim = 7.0
	assert_almost_eq(command.sanitized().aim, 7.0 - TAU, 0.0001, "normal angles still wrap")


func test_garbage_snapshots_decode_to_nothing_or_to_whole_entries() -> void:
	for i in ROUNDS:
		var data: PackedByteArray = _random_bytes(_rng.randi_range(0, 300))
		var result: Dictionary = SnapshotCodec.decode(data)
		if result.is_empty():
			continue
		for entry: SnapshotCodec.Entry in result["entries"]:
			assert_not_null(entry.state)
	pass_test("no crash")


func test_garbage_shop_requests_are_refused_by_the_rules() -> void:
	var upgrades: int = SHOP_CATALOG.upgrades.size()
	var weapons: int = SHOP_CATALOG.weapons.size()
	for index in 256:
		var upgrade: String = ShopRules.check_upgrade(true, SHOP_CATALOG, index, 0, 1000000)
		var weapon: String = ShopRules.check_weapon(true, SHOP_CATALOG, index, -1, 1000000)
		if index >= upgrades:
			assert_eq(upgrade, "No such upgrade.")
		if index >= weapons:
			assert_eq(weapon, "No such weapon.")
	assert_eq(ShopRules.check_upgrade(true, SHOP_CATALOG, -1, 0, 1000000), "No such upgrade.")


func test_garbage_hurt_events_decode_to_nothing_or_to_a_finite_direction() -> void:
	for i in ROUNDS:
		var buffer: StreamPeerBuffer = NetCodec.buffer_from(_random_bytes(_rng.randi_range(0, 24)))
		var hurt: Array = ProjectileSystem.decode_hurt(buffer)
		if not hurt.is_empty():
			assert_true((hurt[0] as Vector2).is_finite(), "direction is finite")
			assert_typeof(hurt[1], TYPE_STRING)
