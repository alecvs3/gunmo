extends GutTest

var pets: PetCatalog


func before_each() -> void:
	pets = PetCatalog.load_default()


func test_the_wizard_deals_arcane_and_the_others_kinetic() -> void:
	for pet in pets.pets:
		var expected: int = DamageType.Type.KINETIC
		if pet.kind == PetData.Kind.WIZARD:
			expected = DamageType.Type.ARCANE
		assert_eq(pet.damage_type, expected, pet.display_name)


func test_three_pets_with_five_rising_tiers() -> void:
	assert_eq(pets.pets.size(), 3)
	var kinds: Array[int] = []
	for pet in pets.pets:
		assert_eq(pet.tiers.size(), PetData.TIERS, pet.display_name)
		assert_false(pet.role.is_empty(), pet.display_name + " has a role")
		kinds.append(pet.kind)
		for i in pet.tiers.size():
			assert_false(pet.tiers[i].description.is_empty())
			if i > 0:
				assert_gt(
					pet.tiers[i].price,
					pet.tiers[i - 1].price,
					"%s tiers cost more" % pet.display_name
				)
	assert_eq(kinds, [PetData.Kind.HEALER, PetData.Kind.WIZARD, PetData.Kind.SOLDIER])


func test_next_price() -> void:
	var healer: PetData = pets.pets[0]
	assert_eq(healer.next_price(0), healer.tiers[0].price)
	assert_eq(healer.next_price(4), healer.tiers[4].price)
	assert_eq(healer.next_price(5), -1, "all bought")


func test_shop_rules_for_pets() -> void:
	var first: int = pets.pets[1].tiers[0].price
	assert_eq(ShopRules.check_pet(true, pets, 1, -1, 0, first), "")
	assert_ne(ShopRules.check_pet(false, pets, 1, -1, 0, 99999), "", "shop closed")
	assert_ne(ShopRules.check_pet(true, pets, 7, -1, 0, 99999), "", "no such pet")
	assert_ne(ShopRules.check_pet(true, pets, 1, -1, 0, first - 1), "", "too poor")
	assert_ne(ShopRules.check_pet(true, pets, 1, 1, 5, 99999), "", "maxed")
	assert_eq(ShopRules.pet_price(pets, 1, 1, 2), pets.pets[1].tiers[2].price, "own pet: next tier")
	assert_eq(ShopRules.pet_price(pets, 0, 1, 2), pets.pets[0].tiers[0].price, "another: tier 1")


func test_loadout_adopts_upgrades_switches_and_resets() -> void:
	var loadout := PlayerLoadout.new()
	assert_null(loadout.pet())
	loadout.buy_pet_tier(2)
	assert_eq([loadout.pet_index, loadout.pet_tier], [2, 1])
	loadout.buy_pet_tier(2)
	assert_eq(loadout.pet_tier, 2)
	loadout.buy_pet_tier(0)
	assert_eq([loadout.pet_index, loadout.pet_tier], [0, 1], "another pet starts again")
	for i in 9:
		loadout.buy_pet_tier(0)
	assert_eq(loadout.pet_tier, PetData.TIERS, "never past the last tier")
	loadout.buy_pet_tier(9)
	assert_eq(loadout.pet_index, 0, "no such pet: nothing changes")
	loadout.load_pet(2, 3)
	assert_eq([loadout.pet_index, loadout.pet_tier], [1, 3], "snapshot: index + 1")
	loadout.load_pet(77, 3)
	assert_eq([loadout.pet_index, loadout.pet_tier], [-1, 0], "junk from a snapshot: no pet")
	loadout.free()


func test_bots_raise_their_favourite_pet() -> void:
	var loadout := PlayerLoadout.new()
	assert_eq(BotShopping.pet_tier_to_buy(loadout, 200, 1), 1, "adopts its favourite")
	assert_eq(BotShopping.pet_tier_to_buy(loadout, 50, 1), -1, "too poor")
	loadout.buy_pet_tier(2)
	assert_eq(BotShopping.pet_tier_to_buy(loadout, 400, 1), -1, "tier 2 (400) > 2 x upgrade (100)")
	loadout.levels.fill(2)
	assert_eq(
		BotShopping.pet_tier_to_buy(loadout, 400, 1), 2, "upgrades now cost 225: keeps its pet"
	)
	loadout.pet_tier = 5
	assert_eq(BotShopping.pet_tier_to_buy(loadout, 99999, 1), -1, "maxed")
	loadout.free()


func test_menu_texts() -> void:
	var healer: PetData = pets.pets[0]
	var wizard: PetData = pets.pets[1]
	assert_eq(PetPanel.buy_text(healer, 0), "Adopt Healer · 200")
	assert_eq(PetPanel.buy_text(healer, 2), "Tier 3: Triage · 700")
	assert_eq(PetPanel.buy_text(healer, 5), "Healer is at its highest tier")
	assert_eq(PetPanel.switch_warning(null, 0, healer), "")
	assert_eq(PetPanel.switch_warning(healer, 3, healer), "")
	assert_string_contains(PetPanel.switch_warning(wizard, 3, healer), "your Wizard (tier 3)")
	assert_eq(PetTierRow.state_for(0, 2), PetTierRow.State.OWNED)
	assert_eq(PetTierRow.state_for(2, 2), PetTierRow.State.NEXT)
	assert_eq(PetTierRow.state_for(4, 2), PetTierRow.State.LOCKED)
	assert_eq(PetTierRow.status_text(PetTierRow.State.NEXT, 700), "700")
