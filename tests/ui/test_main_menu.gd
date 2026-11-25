extends GutTest


func test_bots_start_at_the_mode_s_own_count() -> void:
	var menu: MainMenu = load("res://ui/main_menu.tscn").instantiate()
	add_child_autofree(menu)
	var spin: SpinBox = menu.get_node("%BotsSpin")
	assert_eq(spin.value, 0.0, "Waves starts with no bots")
	assert_eq(menu.chosen_match().bot_fill_to, 0)
	var select: OptionButton = menu.get_node("%ModeSelect")
	select.select(1)
	select.item_selected.emit(1)
	assert_eq(spin.value, 4.0, "Gun Game fills with bots")
