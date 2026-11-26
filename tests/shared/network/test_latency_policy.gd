extends GutTest
## LatencyPolicy: each mode carries its own, the default turns everything off, and the running
## mode's policy is the one NetworkManager hands to shared code.

const MODE_SCENES: Array[String] = [
	"res://modes/wave_mode.tscn",
	"res://modes/gun_game/gun_game_mode.tscn",
]
const DEFAULT_POLICY: String = "res://shared/network/default_latency_policy.tres"


## A mode with no rules of its own, so it can enter the tree without a level or settings.
class QuietMode:
	extends GameMode

	func _ready() -> void:
		pass


func after_each() -> void:
	NetworkManager.use_latency_policy(null)


func test_every_mode_scene_has_a_policy() -> void:
	for path in MODE_SCENES:
		var mode: GameMode = (load(path) as PackedScene).instantiate()
		assert_not_null(mode.latency_policy, path + " sets latency_policy")
		mode.free()


func test_the_default_policy_turns_everything_off() -> void:
	var policy: LatencyPolicy = load(DEFAULT_POLICY)
	assert_false(policy.predict_hit_effects)
	assert_false(policy.predict_damage_numbers)
	assert_false(policy.snap_close_threats)
	assert_false(policy.predict_own_hurt)
	assert_false(policy.fair_contact)
	assert_false(policy.schedule_windup_shots)


func test_aim_lock_covers_the_latency_each_mode_supports() -> void:
	for path in MODE_SCENES:
		var mode: GameMode = (load(path) as PackedScene).instantiate()
		var policy: LatencyPolicy = mode.latency_policy
		assert_gte(
			policy.aim_lock_seconds,
			policy.victim_rewind / 2.0,
			path + ": shots must reach clients before they fire, at one-way latency"
		)
		mode.free()


func test_network_manager_starts_with_the_default() -> void:
	assert_eq(NetworkManager.latency_policy, load(DEFAULT_POLICY))


func test_a_running_mode_hands_over_its_policy_and_takes_it_back() -> void:
	var policy := LatencyPolicy.new()
	var mode := QuietMode.new()
	mode.latency_policy = policy
	add_child(mode)
	assert_eq(NetworkManager.latency_policy, policy, "set while the mode runs")
	remove_child(mode)
	assert_eq(NetworkManager.latency_policy, load(DEFAULT_POLICY), "default once it leaves")
	mode.free()


func test_null_means_the_default() -> void:
	NetworkManager.use_latency_policy(LatencyPolicy.new())
	NetworkManager.use_latency_policy(null)
	assert_eq(NetworkManager.latency_policy, load(DEFAULT_POLICY))
