extends GutTest
## Every pop-up menu (a scene in ui/ whose root extends HudMenu) looks the same and only one is
## open at a time. New menus are found automatically, so they're checked without editing this.

const UI_FOLDER: String = "res://ui"
## The menus that exist today; more may be added, none should vanish unnoticed.
const KNOWN: Array[String] = ["shop_panel.tscn", "pet_panel.tscn", "path_panel.tscn"]


func test_the_known_menus_are_hud_menus() -> void:
	var found: Array[String] = []
	for menu in _menus():
		found.append(menu.scene_file_path.get_file())
	for file in KNOWN:
		assert_has(found, file, file + " extends HudMenu")


func test_every_hint_looks_the_same() -> void:
	for menu in _menus():
		var hint: Label = menu._hint
		var file: String = menu.scene_file_path.get_file()
		assert_eq(hint.get_theme_font_size("font_size"), HudMenu.HINT_FONT_SIZE, file)
		assert_eq(hint.get_theme_constant("outline_size"), HudMenu.HINT_OUTLINE, file)
		assert_eq(hint.get_theme_color("font_color"), HudMenu.GOLD, file)
		assert_eq(hint.get_theme_color("font_outline_color"), Color.BLACK, file)
		assert_string_contains(hint.text, ": ", file + " hint reads '<key>: <name>'")


func test_hints_do_not_share_a_slot() -> void:
	var slots: Array[int] = []
	for menu in _menus():
		assert_does_not_have(slots, menu._hint_slot(), menu.scene_file_path.get_file())
		slots.append(menu._hint_slot())


func test_every_window_looks_the_same() -> void:
	var expected: StyleBoxFlat = HudMenu.window_style()
	for menu in _menus():
		var style := menu._window.get_theme_stylebox("panel") as StyleBoxFlat
		var file: String = menu.scene_file_path.get_file()
		assert_not_null(style, file)
		assert_eq(style.bg_color, expected.bg_color, file)
		assert_eq(style.border_color, expected.border_color, file)
		assert_eq(style.content_margin_left, expected.content_margin_left, file)
		assert_eq(style.content_margin_top, expected.content_margin_top, file)
		assert_eq(menu._dim.color, HudMenu.DIM_COLOR, file)


func test_opening_one_menu_closes_the_others() -> void:
	var menus: Array[HudMenu] = _menus()
	assert_gt(menus.size(), 1)
	menus[0].open()
	assert_true(HudMenu.any_shown(get_tree()))
	for i in range(1, menus.size()):
		menus[i].open()
		for other in menus:
			assert_eq(other.is_shown(), other == menus[i], other.scene_file_path.get_file())
	menus[-1].close()
	assert_false(HudMenu.any_shown(get_tree()))


## One of each menu scene in ui/, in the tree (freed after the test).
func _menus() -> Array[HudMenu]:
	var found: Array[HudMenu] = []
	for file in DirAccess.get_files_at(UI_FOLDER):
		if not file.ends_with(".tscn"):
			continue
		var node: Node = load(UI_FOLDER.path_join(file)).instantiate()
		if node is HudMenu:
			add_child_autofree(node)
			found.append(node as HudMenu)
		else:
			node.free()
	return found
