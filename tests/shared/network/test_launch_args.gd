extends GutTest


func test_no_args_means_no_action() -> void:
	var result: Dictionary = LaunchArgs.parse(PackedStringArray(), 7777)
	assert_eq(result["action"], LaunchArgs.NONE)


func test_host_uses_default_port() -> void:
	var result: Dictionary = LaunchArgs.parse(PackedStringArray(["--host"]), 7777)
	assert_eq(result["action"], LaunchArgs.HOST)
	assert_eq(result["port"], 7777)


func test_host_with_port() -> void:
	var result: Dictionary = LaunchArgs.parse(PackedStringArray(["--host", "9000"]), 7777)
	assert_eq(result["port"], 9000)


func test_host_ignores_non_port_next_arg() -> void:
	var result: Dictionary = LaunchArgs.parse(PackedStringArray(["--host", "--verbose"]), 7777)
	assert_eq(result["action"], LaunchArgs.HOST)
	assert_eq(result["port"], 7777)


func test_join_address_only() -> void:
	var result: Dictionary = LaunchArgs.parse(PackedStringArray(["--join", "100.1.2.3"]), 7777)
	assert_eq(result["action"], LaunchArgs.JOIN)
	assert_eq(result["address"], "100.1.2.3")
	assert_eq(result["port"], 7777)


func test_join_address_and_port() -> void:
	var result: Dictionary = LaunchArgs.parse(PackedStringArray(["--join", "127.0.0.1:9000"]), 7777)
	assert_eq(result["address"], "127.0.0.1")
	assert_eq(result["port"], 9000)


func test_join_without_address_is_ignored() -> void:
	assert_eq(LaunchArgs.parse(PackedStringArray(["--join"]), 7777)["action"], LaunchArgs.NONE)
	var flag_next: Dictionary = LaunchArgs.parse(PackedStringArray(["--join", "--host"]), 7777)
	assert_eq(flag_next["action"], LaunchArgs.HOST, "--host still wins")


func test_bad_port_in_join_keeps_default() -> void:
	var result: Dictionary = LaunchArgs.parse(PackedStringArray(["--join", "host:99999"]), 7777)
	assert_eq(result["address"], "host:99999")
	assert_eq(result["port"], 7777)


func test_dedicated_with_and_without_port() -> void:
	assert_eq(
		LaunchArgs.parse(PackedStringArray(["--dedicated"]), 7777)["action"], LaunchArgs.DEDICATED
	)
	var with_port: Dictionary = LaunchArgs.parse(PackedStringArray(["--dedicated", "9100"]), 7777)
	assert_eq(with_port["port"], 9100)


func test_net_sim_parses_latency_jitter_and_loss_percent() -> void:
	var args := PackedStringArray(["--join", "1.2.3.4", "--net-sim", "120,15,5"])
	var result: Dictionary = LaunchArgs.parse(args, 7777)
	assert_eq(result["action"], LaunchArgs.JOIN)
	assert_eq(result["net_sim"][0], 120)
	assert_eq(result["net_sim"][1], 15)
	assert_almost_eq(result["net_sim"][2], 0.05, 0.0001)


func test_bad_net_sim_is_ignored() -> void:
	for bad in ["120,15", "a,b,c", "120,15,x"]:
		var result: Dictionary = LaunchArgs.parse(PackedStringArray(["--net-sim", bad]), 7777)
		assert_eq(result["net_sim"], [], bad)
	assert_eq(LaunchArgs.parse(PackedStringArray(["--net-sim"]), 7777)["net_sim"], [])


func test_match_settings_path() -> void:
	var args := PackedStringArray(["--host", "--match", "res://tests/net/data/quick_match.tres"])
	var result: Dictionary = LaunchArgs.parse(args, 7777)
	assert_eq(result["action"], LaunchArgs.HOST)
	assert_eq(result["match"], "res://tests/net/data/quick_match.tres")
	assert_eq(LaunchArgs.parse(PackedStringArray(["--host"]), 7777)["match"], "")
