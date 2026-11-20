extends GutTest

var host_hello: Dictionary


func before_each() -> void:
	host_hello = Handshake.make_hello("0.1.0", "abc123")


func test_matching_hello_is_accepted() -> void:
	var reason: String = Handshake.check_hello(host_hello.duplicate(), host_hello, 1, 8, true)
	assert_eq(reason, "")


func test_different_protocol_is_rejected() -> void:
	var hello: Dictionary = host_hello.duplicate()
	hello["protocol"] = Handshake.PROTOCOL + 1
	assert_string_contains(Handshake.check_hello(hello, host_hello, 1, 8, true), "Incompatible")


func test_different_version_is_rejected_with_both_versions() -> void:
	var reason: String = Handshake.check_hello(
		Handshake.make_hello("0.2.0", "abc123"), host_hello, 1, 8, true
	)
	assert_string_contains(reason, "0.1.0")
	assert_string_contains(reason, "0.2.0")


func test_different_build_is_rejected_when_required() -> void:
	var hello: Dictionary = Handshake.make_hello("0.1.0", "zzz999")
	assert_string_contains(Handshake.check_hello(hello, host_hello, 1, 8, true), "build")


func test_different_build_is_allowed_when_not_required() -> void:
	var hello: Dictionary = Handshake.make_hello("0.1.0", "zzz999")
	assert_eq(Handshake.check_hello(hello, host_hello, 1, 8, false), "")


func test_release_builds_compare_by_version_only() -> void:
	var hello: Dictionary = Handshake.make_hello("0.1.0", BuildInfo.RELEASE)
	assert_eq(Handshake.check_hello(hello, host_hello, 1, 8, true), "")


func test_full_lobby_is_rejected() -> void:
	var reason: String = Handshake.check_hello(host_hello.duplicate(), host_hello, 8, 8, true)
	assert_string_contains(reason, "full")
	assert_eq(Handshake.check_hello(host_hello.duplicate(), host_hello, 7, 8, true), "")


func test_missing_fields_are_rejected_not_crashing() -> void:
	assert_ne(Handshake.check_hello({}, host_hello, 1, 8, true), "")


func test_encode_decode_round_trip() -> void:
	var decoded: Dictionary = Handshake.decode(Handshake.encode(host_hello))
	assert_eq(decoded, host_hello)


func test_decode_garbage_returns_empty() -> void:
	assert_eq(Handshake.decode(PackedByteArray([1, 2, 3])), {}, "too short")
	assert_eq(Handshake.decode(var_to_bytes([1, 2])), {}, "non-dictionary payload")


func test_reject_and_accept_messages() -> void:
	assert_true(Handshake.accept()["ok"])
	assert_false(Handshake.reject("nope")["ok"])
	assert_eq(Handshake.reject("nope")["reason"], "nope")
