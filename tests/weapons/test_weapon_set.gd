extends GutTest

var catalog: ShopCatalog


func before_each() -> void:
	catalog = ShopCatalog.load_default()


func _named(display_name: String) -> WeaponData:
	for weapon in catalog.weapons:
		if weapon.display_name == display_name:
			return weapon
	return null


func test_everyone_starts_with_a_free_pistol() -> void:
	assert_eq(catalog.weapon(0).display_name, "Pistol")
	assert_eq(catalog.weapon(0).price, 0)


func test_damage_types() -> void:
	for weapon in catalog.weapons:
		var expected: int = DamageType.Type.KINETIC
		if weapon.display_name == "Rocket Launcher":
			expected = DamageType.Type.BLAST
		assert_eq(weapon.damage_type, expected, weapon.display_name)


func test_weapons_play_differently() -> void:
	var pistol: WeaponData = _named("Pistol")
	var smg: WeaponData = _named("SMG")
	var shotgun: WeaponData = _named("Shotgun")
	var rifle: WeaponData = _named("Rifle")
	assert_gt(smg.fire_rate, pistol.fire_rate, "SMG fires fastest")
	assert_gt(smg.spread, pistol.spread, "SMG is less accurate")
	assert_gt(shotgun.pellets, 1, "shotgun fires pellets")
	assert_lt(shotgun.bullet_lifetime, pistol.bullet_lifetime, "shotgun is short range")
	assert_gt(rifle.pierce, 0, "rifle pierces")
	assert_gt(rifle.damage, pistol.damage * 2, "rifle hits hard")
	for weapon in [smg, shotgun, rifle]:
		assert_gt(weapon.price, 0, weapon.display_name + " costs credits")


func test_index_is_clamped() -> void:
	assert_eq(catalog.weapon(-5), catalog.weapons[0])
	assert_eq(catalog.weapon(999), catalog.weapons.back())
	assert_false(catalog.is_weapon_index(catalog.weapons.size()))


func test_loadout_equips_with_full_magazine_and_pose() -> void:
	var weapon := WeaponComponent.new()
	weapon.weapon_data = catalog.weapon(0)
	var look := PlayerLook.new()
	var health := HealthComponent.new()
	var loadout := PlayerLoadout.new()
	loadout.weapon = weapon
	loadout.health = health
	loadout.look = look
	for node: Node in [weapon, health, look, loadout]:
		add_child_autofree(node)
	weapon.ammo = 1
	loadout.equip_weapon(2)
	assert_eq(weapon.weapon_data.display_name, catalog.weapon(2).display_name)
	assert_ne(weapon.weapon_data, catalog.weapon(2), "an upgraded copy, never the shared file")
	assert_eq(weapon.ammo, catalog.weapon(2).magazine_size)
	assert_eq(look.pose, catalog.weapon(2).pose)
	loadout.load_state(2, loadout.levels)
	assert_eq(weapon.ammo, catalog.weapon(2).magazine_size, "same weapon: no change")
	loadout.reset()
	assert_eq(loadout.weapon_index, 0)


func test_rocket_launcher_is_a_slow_exploding_rocket() -> void:
	var rocket: WeaponData = _named("Rocket Launcher")
	var pistol: WeaponData = _named("Pistol")
	assert_not_null(rocket)
	assert_true(rocket.explodes())
	assert_false(pistol.explodes(), "plain guns don't explode")
	assert_eq(rocket.projectile, WeaponData.Projectile.ROCKET)
	assert_not_null(rocket.held_model, "drawn as a tube")
	assert_lt(rocket.bullet_speed, pistol.bullet_speed, "rockets are slow")
	assert_gt(rocket.bullet_radius, pistol.bullet_radius, "rockets are big")
	assert_gt(rocket.price, 0)


func test_rocket_launcher_is_on_the_gun_game_ladder() -> void:
	var settings: MatchSettings = load("res://modes/data/gun_game_match.tres")
	assert_has(settings.ladder, _named("Rocket Launcher"))
	assert_eq(settings.ladder.back().display_name, "Pistol", "the ladder still ends on the pistol")


func test_every_projectile_kind_has_a_scene() -> void:
	assert_eq(ProjectileSystem.PROJECTILE_SCENES.size(), WeaponData.Projectile.size())
	for scene: PackedScene in ProjectileSystem.PROJECTILE_SCENES:
		var projectile: Node = scene.instantiate()
		assert_true(projectile is Bullet, scene.resource_path + " flies as a Bullet")
		projectile.free()


func test_guns_draw_their_own_model_and_bullet() -> void:
	var expected: Dictionary = {
		"Pistol": WeaponData.Projectile.BULLET,
		"SMG": WeaponData.Projectile.BULLET,
		"Shotgun": WeaponData.Projectile.PELLET,
		"Rifle": WeaponData.Projectile.RIFLE_ROUND,
	}
	for display_name: String in expected:
		var weapon: WeaponData = _named(display_name)
		assert_not_null(weapon.held_model, display_name + " has its own model")
		assert_eq(weapon.projectile, expected[display_name], display_name + " bullet look")
