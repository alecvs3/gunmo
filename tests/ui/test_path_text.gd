extends GutTest
## The Path window's text, how it draws a node, and where the board puts every node.

var tree: PathTree = PathTree.load_default()


func _named(node_name: String) -> int:
	for i in tree.nodes.size():
		if tree.node(i).display_name == node_name:
			return i
	return -1


func test_cores_text() -> void:
	assert_eq(PathDetail.cores_text(1), "1 Core")
	assert_eq(PathDetail.cores_text(0), "0 Cores")
	assert_eq(PathDetail.cores_text(3), "3 Cores")


func test_detail_text() -> void:
	var quick: PathNode = tree.node(_named("Quick hands"))
	assert_eq(PathDetail.where_text(quick), "Tier II · Logistics")
	assert_eq(PathDetail.requires_text(quick), "Requires: Fortitude")
	assert_eq(PathDetail.requires_text(tree.node(_named("Fortitude"))), "Requires: nothing")
	assert_eq(PathDetail.rivals_text(tree, _named("Quick hands")), "Locks out: none")
	assert_eq(PathDetail.rivals_text(tree, _named("Scavenger")), "Locks out: Fleet foot")
	assert_eq(PathDetail.rivals_text(tree, _named("Fleet foot")), "Locks out: Scavenger")


func test_team_text() -> void:
	assert_eq(PathNodeToken.team_text([] as Array[String]), "")
	assert_eq(PathNodeToken.team_text(["Ana", "Bo"] as Array[String]), "Team: Ana, Bo")
	assert_eq(PathNodeToken.team_colour("Ana"), PathNodeToken.team_colour("Ana"))


func test_step_and_take_text() -> void:
	assert_string_contains(PathPanel.step_text(false, false), "between waves")
	assert_string_contains(PathPanel.step_text(true, true), "took this break's step")
	assert_string_contains(PathPanel.step_text(true, false), "One step this break")
	var quick: PathNode = tree.node(_named("Quick hands"))
	assert_eq(
		PathDetail.take_text(quick, PathRules.Status.AVAILABLE, ""), "Take Quick hands · 2 Cores"
	)
	assert_eq(
		PathDetail.take_text(quick, PathRules.Status.OWNED, ""), "Quick hands is on your Path"
	)
	assert_eq(PathDetail.take_text(quick, PathRules.Status.LOCKED, "Needs X."), "Needs X.")


func test_look_shows_locked_out_over_status() -> void:
	var looks: Array[PathTokenArt.Look] = [
		PathTokenArt.look(PathRules.Status.OWNED, false),
		PathTokenArt.look(PathRules.Status.AVAILABLE, false),
		PathTokenArt.look(PathRules.Status.LOCKED, false),
		PathTokenArt.look(PathRules.Status.LOCKED, true),
	]
	assert_eq(Array(looks), PathTokenArt.Look.values())
	assert_eq(PathTokenArt.NAMES.size(), PathTokenArt.Look.size())
	assert_eq(PathTokenArt.COLOURS.size(), PathTokenArt.Look.size())


func test_every_node_has_its_own_board_spot() -> void:
	var seen: Dictionary = {}
	for i in tree.nodes.size():
		var at: Vector2 = tree.node(i).board_position
		assert_false(
			seen.has(at), "%s shares a spot with %s" % [tree.node(i).display_name, seen.get(at)]
		)
		seen[at] = tree.node(i).display_name


func test_deeper_tiers_sit_higher_on_the_board() -> void:
	for i in tree.nodes.size():
		for needed in tree.node(i).requires:
			var below: float = PathBoard.spot(tree, tree.index_of(needed)).y
			assert_lt(
				PathBoard.spot(tree, i).y, below, tree.node(i).display_name + " above what it needs"
			)


func test_board_fits_every_node() -> void:
	var board := Rect2(Vector2.ZERO, PathBoard.board_size(tree))
	for i in tree.nodes.size():
		var token := Rect2(PathBoard.spot(tree, i) - PathNodeToken.CENTRE, PathNodeToken.SIZE)
		assert_true(board.encloses(token), tree.node(i).display_name + " on the board")
