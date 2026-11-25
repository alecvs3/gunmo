extends GutTest
## The rules that pick a change's smoke scenarios (tools/check_scope.json) and how they decide.

const SMOKE_RUNNER: String = "res://tests/net/run_smoke.ps1"
const SKIP_FOLDERS: Array[String] = [".godot", ".git"]

var rules: Dictionary


func before_each() -> void:
	rules = CheckScope.load_rules()


func _decide(files: Array[String]) -> CheckScope.Decision:
	return CheckScope.decide(PackedStringArray(files), rules)


func test_rules_name_only_scenarios_the_smoke_runner_has() -> void:
	var runner: String = FileAccess.get_file_as_string(SMOKE_RUNNER)
	var listed: Array = rules["scenarios"]
	for letter: String in listed:
		assert_string_contains(runner, 'Id = "%s"' % letter, "run_smoke.ps1 has scenario " + letter)
	for key: String in rules["paths"]:
		var value: Variant = rules["paths"][key]
		if value is Array:
			for letter: String in value:
				assert_has(listed, letter, "%s names a real scenario" % key)
		else:
			assert_eq(value, "all", key + ': a list of scenarios or "all"')


func test_every_project_folder_has_a_rule() -> void:
	for folder in DirAccess.get_directories_at("res://"):
		if folder in SKIP_FOLDERS:
			continue
		var key: String = CheckScope.match_key(folder + "/x.gd", rules["paths"])
		assert_ne(key, "", "%s/ needs a rule in tools/check_scope.json" % folder)


func test_docs_need_no_smoke() -> void:
	var decision: CheckScope.Decision = _decide(["docs/PROGRESS.md", "pets/CLAUDE.md"])
	assert_false(decision.full)
	assert_eq(decision.scenarios, [] as Array[String])


func test_a_folder_picks_its_scenarios_in_order() -> void:
	var decision: CheckScope.Decision = _decide(["pets/wizard_powers.gd", "upgrades/shop_rules.gd"])
	assert_false(decision.full)
	assert_eq(decision.scenarios, ["C", "D", "F"] as Array[String])


func test_the_longest_path_wins() -> void:
	assert_eq(_decide(["tests/net/latency.gd"]).scenarios, ["G"] as Array[String])
	assert_true(_decide(["tests/net/data/latency_match.tres"]).full, "other tests/net files: all")


func test_a_uid_file_follows_its_script() -> void:
	assert_eq(CheckScope.match_key("ui/hud.gd.uid", rules["paths"]), "ui/")


func test_netcode_and_unknown_files_need_everything() -> void:
	assert_true(_decide(["shared/network/net_clock.gd"]).full)
	assert_true(_decide(["gdlintrc"]).full, "a file in no rule")
	assert_eq(_decide(["gdlintrc"]).scenarios.size(), rules["scenarios"].size())


func test_a_big_change_needs_everything() -> void:
	var files: Array[String] = []
	for i in int(rules["big_change_files"]) + 1:
		files.append("ui/screen_%d.gd" % i)
	var decision: CheckScope.Decision = _decide(files)
	assert_true(decision.full)
	assert_string_contains(decision.reasons[0], "big change")
