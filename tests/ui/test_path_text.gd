extends GutTest
## The Path window's text.

var tree: PathTree = PathTree.load_default()


func test_cores_text() -> void:
	assert_eq(PathNodeCard.cores_text(1), "1 Core")
	assert_eq(PathNodeCard.cores_text(0), "0 Cores")
	assert_eq(PathNodeCard.cores_text(3), "3 Cores")


func test_card_text() -> void:
	var fortitude: PathNode = tree.nodes[0]
	assert_eq(
		PathNodeCard.card_text(fortitude, PathRules.Status.AVAILABLE, ""),
		"Fortitude\nTier 1 · 1 Core · Available"
	)
	assert_eq(
		PathNodeCard.card_text(fortitude, PathRules.Status.OWNED, "Team: Ana"),
		"Fortitude\nTier 1 · 1 Core · Owned\nTeam: Ana"
	)
	assert_eq(PathNodeCard.team_text([] as Array[String]), "")
	assert_eq(PathNodeCard.team_text(["Ana", "Bo"] as Array[String]), "Team: Ana, Bo")


func test_step_and_take_text() -> void:
	assert_string_contains(PathPanel.step_text(false, false), "between waves")
	assert_string_contains(PathPanel.step_text(true, true), "took this break's step")
	assert_string_contains(PathPanel.step_text(true, false), "One step this break")
	var quick: PathNode = tree.nodes[1]
	assert_eq(
		PathPanel.take_text(quick, PathRules.Status.AVAILABLE, ""), "Take Quick hands · 2 Cores"
	)
	assert_eq(PathPanel.take_text(quick, PathRules.Status.OWNED, ""), "Quick hands is on your Path")
	assert_eq(PathPanel.take_text(quick, PathRules.Status.LOCKED, "Needs X."), "Needs X.")


func test_branch_nodes_go_by_tier() -> void:
	assert_eq(PathPanel.branch_nodes(tree, "Logistics"), [0, 1, 2, 3, 4] as Array[int])
	assert_eq(PathPanel.branch_nodes(tree, "Nothing"), [] as Array[int])
