extends GutTest
## Safety net for the project's wiring, so mistakes that only show up when playing fail here:
##   - every data .tres loads and has sensible numbers (Godot drops fields equal to the script
##     default when saving, which can silently zero a value)
##   - every mode scene a match can run, and every level, is in Main's spawners
##   - every EventBus signal is both emitted and connected somewhere in the game code

const SKIP_FOLDERS: Array[String] = ["res://.godot", "res://addons", "res://export"]


func test_every_data_file_loads_and_is_valid() -> void:
	var checked: int = 0
	for path in _files("res://", ".tres"):
		var resource: Resource = load(path)
		assert_not_null(resource, "%s loads" % path)
		if resource == null:
			continue
		for problem in _problems(resource):
			fail_test("%s: %s" % [path, problem])
		checked += 1
	assert_gt(checked, 20, "found the data files")


func test_every_match_mode_and_level_is_spawnable() -> void:
	var spawnable: Dictionary = _main_spawnable_scenes()
	assert_true(spawnable.has("ModeSpawner") and spawnable.has("LevelSpawner"))
	for path in _files("res://", ".tres"):
		var settings := load(path) as MatchSettings
		if settings != null and settings.mode_scene != null:
			assert_has(
				spawnable["ModeSpawner"], settings.mode_scene.resource_path, "%s's mode" % path
			)
	for path in _files("res://levels", ".tscn"):
		assert_has(spawnable["LevelSpawner"], path, "level %s" % path)
	for list: PackedStringArray in spawnable.values():
		for scene in list:
			assert_true(ResourceLoader.exists(scene), "spawnable %s exists" % scene)


func test_every_event_bus_signal_is_emitted_and_connected() -> void:
	var code: String = ""
	for path in _files("res://", ".gd"):
		if not path.begins_with("res://tests") and path != "res://autoloads/event_bus.gd":
			code += FileAccess.get_file_as_string(path) + "\n"
	var bus: Script = load("res://autoloads/event_bus.gd")
	for info in bus.get_script_signal_list():
		var name: String = info["name"]
		assert_true(code.contains("EventBus.%s.emit" % name), "%s is emitted" % name)
		assert_true(code.contains("EventBus.%s.connect" % name), "%s is connected" % name)


## What is wrong with one data resource (empty = fine).
func _problems(resource: Resource) -> Array[String]:
	var problems: Array[String] = []
	if resource is WeaponData:
		var weapon := resource as WeaponData
		_need(problems, not weapon.display_name.is_empty(), "no display_name")
		_need(problems, weapon.damage > 0 and weapon.fire_rate > 0.0, "damage/fire_rate")
		_need(problems, weapon.magazine_size > 0 and weapon.bullet_speed > 1.0, "magazine/speed")
	elif resource is EnemyData:
		var enemy := resource as EnemyData
		_need(problems, enemy.spawn_weight > 0.0, "spawn_weight")
		_need(problems, enemy.max_health > 0, "max_health")
		_need(problems, enemy.movement != null and enemy.attack != null, "no movement/attack")
	elif resource is UpgradeData:
		var upgrade := resource as UpgradeData
		var weapon_stat: bool = UpgradeData.is_weapon_stat(upgrade.stat)
		_need(problems, weapon_stat or upgrade.per_level > 0.0, "player stat without per_level")
		_need(problems, upgrade.base_cost > 0, "base_cost")
	elif resource is ShopCatalog:
		var catalog := resource as ShopCatalog
		_need(problems, not catalog.weapons.is_empty(), "no weapons")
		_need(problems, catalog.upgrades.size() <= ShopCatalog.MAX_UPGRADES, "too many upgrades")
		_need(problems, not (null in catalog.weapons or null in catalog.upgrades), "empty slot")
	elif resource is MatchSettings:
		_need(problems, (resource as MatchSettings).mode_scene != null, "no mode_scene")
	elif resource is BotProfile:
		var profile := resource as BotProfile
		_need(problems, not profile.display_name.is_empty(), "no display_name")
		_need(problems, profile.awareness_range > 0.0, "awareness_range")
	elif resource is WaveSchedule:
		var schedule := resource as WaveSchedule
		_need(problems, schedule.total_waves > 0 and schedule.max_alive > 0, "waves/max_alive")
	return problems


func _need(problems: Array[String], ok: bool, problem: String) -> void:
	if not ok:
		problems.append(problem)


## Main.tscn's spawners: spawner node name -> its spawnable scene paths. Read from the packed
## scene without instantiating it.
func _main_spawnable_scenes() -> Dictionary:
	var state: SceneState = (load("res://main.tscn") as PackedScene).get_state()
	var found: Dictionary = {}
	for node in state.get_node_count():
		if state.get_node_type(node) != &"MultiplayerSpawner":
			continue
		for property in state.get_node_property_count(node):
			if state.get_node_property_name(node, property) == &"_spawnable_scenes":
				found[String(state.get_node_name(node))] = state.get_node_property_value(
					node, property
				)
	return found


## Every file under `folder` ending in `extension` (game folders only).
func _files(folder: String, extension: String) -> Array[String]:
	var found: Array[String] = []
	var directory := DirAccess.open(folder)
	if directory == null:
		return found
	for file in directory.get_files():
		if file.ends_with(extension):
			found.append(folder.path_join(file))
	for sub in directory.get_directories():
		var path: String = folder.path_join(sub)
		if path not in SKIP_FOLDERS and not sub.begins_with("."):
			found.append_array(_files(path, extension))
	return found
