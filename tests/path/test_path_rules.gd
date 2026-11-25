extends GutTest
## PathRules: requirements, exclusions, one step per break, early calls, Cores, no respec.
## A made-up tree: root (1 Core) -> left (2) and right (2); deep (3) needs left and excludes
## right.

var tree: PathTree
var progress: PathProgress


func _node(node_name: String, tier: int, cost: int) -> PathNode:
	var path_node := PathNode.new()
	path_node.display_name = node_name
	path_node.branch = "Test"
	path_node.tier = tier
	path_node.core_cost = cost
	return path_node


func before_each() -> void:
	var root: PathNode = _node("Root", 1, 1)
	var left: PathNode = _node("Left", 2, 2)
	var right: PathNode = _node("Right", 2, 2)
	var deep: PathNode = _node("Deep", 3, 3)
	left.requires.assign([root])
	right.requires.assign([root])
	deep.requires.assign([left])
	deep.excludes.assign([right])
	tree = PathTree.new()
	tree.nodes.assign([root, left, right, deep])
	progress = PathProgress.new()
	progress.cores = 20


## A break starts and the player takes `index` in it.
func _take_in_new_break(index: int) -> bool:
	PathRules.start_break(progress)
	return PathRules.take(tree, progress, index, true)


func test_taking_spends_cores_and_owns_the_node() -> void:
	assert_eq(PathRules.check(tree, progress, 0, true), "")
	assert_true(PathRules.take(tree, progress, 0, true))
	assert_true(progress.owns(0))
	assert_eq(progress.cores, 19)
	assert_true(progress.stepped)


func test_requirements_must_be_owned_first() -> void:
	assert_string_contains(PathRules.check(tree, progress, 1, true), "Needs Root")
	assert_true(_take_in_new_break(0))
	assert_true(_take_in_new_break(1))
	assert_string_contains(PathRules.check(tree, progress, 3, false), "between waves")


func test_exclusions_lock_both_ways() -> void:
	for index in [0, 1, 3]:
		assert_true(_take_in_new_break(index))
	PathRules.start_break(progress)
	assert_string_contains(PathRules.check(tree, progress, 2, true), "Locked out by Deep")
	var other := PathProgress.new()
	other.cores = 20
	other.owned = 0b0101  # root and right
	assert_string_contains(PathRules.check(tree, other, 3, true), "Locked out by Right")


func test_rivals_and_locked_out_work_both_ways() -> void:
	assert_eq(tree.rivals(2), [3] as Array[int])
	assert_eq(tree.rivals(3), [2] as Array[int])
	assert_eq(tree.rivals(0), [] as Array[int])
	assert_eq(tree.rivals(99), [] as Array[int])
	assert_false(PathRules.is_locked_out(tree, progress, 2))
	progress.owned = 0b1011  # root, left and deep
	assert_true(PathRules.is_locked_out(tree, progress, 2))
	assert_false(PathRules.is_locked_out(tree, progress, 3), "an owned node is never locked out")
	assert_false(PathRules.is_locked_out(tree, progress, 1), "a plain node is never locked out")


func test_one_step_per_break() -> void:
	assert_true(_take_in_new_break(0))
	assert_string_contains(PathRules.check(tree, progress, 1, true), "One step per break")
	assert_false(PathRules.take(tree, progress, 1, true))
	PathRules.start_break(progress)
	assert_true(PathRules.take(tree, progress, 1, true), "the next break gives a new step")


func test_no_step_during_a_wave_and_an_early_call_skips_the_break() -> void:
	PathRules.start_break(progress)
	assert_false(PathRules.take(tree, progress, 0, false), "during a wave")
	# Wave N is called early into wave N + 1: no break started, so still no step.
	assert_string_contains(PathRules.check(tree, progress, 0, false), "between waves")
	assert_true(_take_in_new_break(0), "the break after the called wave gives one step")
	assert_false(PathRules.take(tree, progress, 1, true), "only one, however many were skipped")


func test_not_enough_cores() -> void:
	progress.cores = 0
	assert_string_contains(PathRules.check(tree, progress, 0, true), "Cores")
	progress.cores = 1
	assert_true(_take_in_new_break(0))
	assert_eq(progress.cores, 0)
	PathRules.start_break(progress)
	assert_string_contains(PathRules.check(tree, progress, 1, true), "Cores")


func test_no_respec_and_no_junk() -> void:
	assert_true(_take_in_new_break(0))
	PathRules.start_break(progress)
	assert_string_contains(PathRules.check(tree, progress, 0, true), "Already")
	assert_false(PathRules.take(tree, progress, 0, true))
	assert_eq(progress.owned, 1, "owned nodes never go away")
	for index in [-1, 4, 63, 64, 255]:
		assert_string_contains(PathRules.check(tree, progress, index, true), "No such")


func test_status() -> void:
	PathRules.start_break(progress)
	assert_eq(PathRules.status(tree, progress, 0, true), PathRules.Status.AVAILABLE)
	assert_eq(PathRules.status(tree, progress, 1, true), PathRules.Status.LOCKED)
	PathRules.take(tree, progress, 0, true)
	assert_eq(PathRules.status(tree, progress, 0, true), PathRules.Status.OWNED)
	assert_eq(PathRules.status(tree, progress, 1, true), PathRules.Status.LOCKED, "step used")


func test_bit_63_is_a_node_like_any_other() -> void:
	var big := PathTree.new()
	for i in PathTree.MAX_NODES:
		big.nodes.append(_node("N%d" % i, 1, 0))
	PathRules.start_break(progress)
	assert_true(PathRules.take(big, progress, 63, true))
	assert_true(progress.owns(63))
	assert_false(progress.owns(62))


func test_wave_cores_and_the_solo_bonus() -> void:
	var settings := MatchSettings.new()
	settings.cores_per_wave = 1
	settings.cores_solo_bonus = 1
	settings.cores_solo_every = 5
	assert_eq(PathRules.wave_cores(settings, 4, true), 1)
	assert_eq(PathRules.wave_cores(settings, 5, true), 2, "solo: every 5th wave")
	assert_eq(PathRules.wave_cores(settings, 10, true), 2)
	assert_eq(PathRules.wave_cores(settings, 5, false), 1, "not solo")
	settings.cores_solo_every = 0
	assert_eq(PathRules.wave_cores(settings, 5, true), 1, "0 = no bonus")
	assert_true(PathRules.is_solo(1, 0))
	assert_false(PathRules.is_solo(1, 1), "a bot partner")
	assert_false(PathRules.is_solo(2, 0))


func test_solo_run_earns_more_cores() -> void:
	var settings: MatchSettings = load("res://modes/data/default_match.tres")
	var solo: int = 0
	var duo: int = 0
	for wave in range(1, 26):
		solo += PathRules.wave_cores(settings, wave, true)
		duo += PathRules.wave_cores(settings, wave, false)
	assert_eq(duo, 25)
	assert_eq(solo, 30, "+1 on waves 5, 10, 15, 20, 25")


func test_boss_cores_include_the_paths_extra() -> void:
	var settings := MatchSettings.new()
	settings.cores_per_boss = 2
	var scavenger := EconomyEffect.new()
	scavenger.boss_cores = 1
	tree.nodes[0].effects.assign([scavenger])
	assert_eq(PathRules.boss_cores(settings, tree, progress), 2)
	progress.owned = 1
	assert_eq(PathRules.boss_cores(settings, tree, progress), 3)
