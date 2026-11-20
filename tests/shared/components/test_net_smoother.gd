extends GutTest

var body: Node2D
var smoother: NetSmoother


func before_each() -> void:
	body = Node2D.new()
	smoother = NetSmoother.new()
	body.add_child(smoother)
	add_child_autofree(body)
	smoother.set_physics_process(false)


func test_host_copies_body_position_into_target() -> void:
	body.position = Vector2(40, 50)
	smoother._physics_process(0.016)
	assert_eq(smoother.target_position, Vector2(40, 50))


func test_client_glides_part_way_toward_small_moves() -> void:
	smoother.target_position = Vector2(50, 0)
	smoother.step_toward_target(0.016)
	assert_gt(body.position.x, 0.0)
	assert_lt(body.position.x, 50.0)


func test_client_reaches_target_over_time() -> void:
	smoother.target_position = Vector2(50, 0)
	for i in 120:
		smoother.step_toward_target(0.016)
	assert_almost_eq(body.position.x, 50.0, 0.1)


func test_client_snaps_on_big_jumps() -> void:
	var far: float = NetworkManager.config.snap_distance + 1.0
	smoother.target_position = Vector2(far, 0)
	smoother.step_toward_target(0.016)
	assert_eq(body.position, Vector2(far, 0))


func test_snap_always_keeps_local_player_exact() -> void:
	smoother.snap_always = true
	smoother.target_position = Vector2(5, 0)
	smoother.step_toward_target(0.016)
	assert_eq(body.position, Vector2(5, 0))
