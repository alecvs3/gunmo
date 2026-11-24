extends GutTest
## The shop's looks: which purchase pops, how gun pictures fit their card, how wide the dots are.


func _seen(weapon: int, levels: Array[int]) -> ShopSeen:
	var seen := ShopSeen.new()
	seen.weapon_index = weapon
	seen.levels = levels
	return seen


func test_only_a_confirmed_purchase_pops() -> void:
	var before: ShopSeen = _seen(0, [1, 0] as Array[int])
	assert_eq(before.weapon_bought(_seen(0, [1, 0] as Array[int])), -1, "nothing changed")
	assert_eq(before.weapon_bought(_seen(2, [1, 0] as Array[int])), 2, "a new gun")
	assert_true(before.level_bought(_seen(0, [1, 1] as Array[int]), 1), "a new level")
	assert_false(before.level_bought(_seen(0, [1, 1] as Array[int]), 0), "another upgrade")
	assert_false(before.level_bought(_seen(0, [0, 0] as Array[int]), 0), "a reset is no purchase")
	assert_false(before.level_bought(_seen(0, [1, 0] as Array[int]), 5), "no such upgrade")


func test_every_gun_picture_fits_its_box() -> void:
	var box := Vector2(138, 44)
	for weapon in ShopCatalog.load_default().weapons:
		assert_not_null(weapon.held_model, "%s has a model to show" % weapon.display_name)
		var model := weapon.held_model.instantiate() as Node2D
		var bounds: Rect2 = ShopGunPicture.model_bounds(model)
		var factor: float = ShopGunPicture.fit_scale(bounds, box)
		assert_gt(bounds.size.x, 0.0, weapon.display_name)
		assert_true(bounds.size.x * factor <= box.x + 0.01, "%s fits across" % weapon.display_name)
		assert_true(bounds.size.y * factor <= box.y + 0.01, "%s fits down" % weapon.display_name)
		model.free()


func test_model_bounds_follow_child_positions() -> void:
	var root := Node2D.new()
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 4)])
	shape.position = Vector2(-20, 2)
	root.add_child(shape)
	assert_eq(ShopGunPicture.model_bounds(root), Rect2(-20, 2, 10, 4))
	root.free()


func test_dots_width() -> void:
	assert_eq(ShopPips.width_for(1), ShopPips.DOT)
	assert_eq(ShopPips.width_for(5), 5 * ShopPips.DOT + 4 * ShopPips.GAP)
	assert_eq(ShopPips.width_for(0), 0.0)
