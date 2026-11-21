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


func test_loadout_equips_with_full_magazine_and_color() -> void:
	var weapon := WeaponComponent.new()
	weapon.weapon_data = catalog.weapon(0)
	var barrel := Polygon2D.new()
	var loadout := PlayerLoadout.new()
	loadout.weapon = weapon
	loadout.barrel = barrel
	for node: Node in [weapon, barrel, loadout]:
		add_child_autofree(node)
	weapon.ammo = 1
	loadout.equip_weapon(2)
	assert_eq(weapon.weapon_data, catalog.weapon(2))
	assert_eq(weapon.ammo, catalog.weapon(2).magazine_size)
	assert_eq(barrel.color, catalog.weapon(2).color)
	loadout.load_state(2)
	assert_eq(weapon.ammo, catalog.weapon(2).magazine_size, "same weapon: no change")
	loadout.reset()
	assert_eq(loadout.weapon_index, 0)
