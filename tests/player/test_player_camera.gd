extends GutTest


func test_locked_follow_lands_exactly_on_target() -> void:
	var result: Vector2 = PlayerCamera.follow(Vector2.ZERO, Vector2(100, 50), 0.016, 0.0)
	assert_eq(result, Vector2(100, 50))


func test_smoothed_follow_moves_part_way() -> void:
	var result: Vector2 = PlayerCamera.follow(Vector2.ZERO, Vector2(100, 0), 0.016, 0.1)
	assert_gt(result.x, 0.0)
	assert_lt(result.x, 100.0)


func test_smoothed_follow_is_frame_rate_independent() -> void:
	var at_60_hz: Vector2 = Vector2.ZERO
	var at_180_hz: Vector2 = Vector2.ZERO
	for i in 60:
		at_60_hz = PlayerCamera.follow(at_60_hz, Vector2(100, 0), 1.0 / 60.0, 0.1)
	for i in 180:
		at_180_hz = PlayerCamera.follow(at_180_hz, Vector2(100, 0), 1.0 / 180.0, 0.1)
	assert_almost_eq(at_60_hz.x, at_180_hz.x, 0.001, "one second feels the same at any Hz")


func test_camera_snaps_and_follows_body() -> void:
	var body := Node2D.new()
	body.position = Vector2(300, 200)
	add_child_autofree(body)
	var camera := PlayerCamera.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	camera.top_level = true
	camera.body = body
	body.add_child(camera)
	assert_eq(camera.global_position, Vector2(300, 200), "starts on the body")
	body.position = Vector2(305, 200)
	camera._physics_process(0.016)
	assert_almost_eq(
		camera.drawn_position().x, 300.0 + 5.0 * Engine.get_physics_interpolation_fraction(), 0.001
	)
	body.position = Vector2(900, 200)
	camera._physics_process(0.016)
	assert_eq(camera.drawn_position(), Vector2(900, 200), "a teleport snaps")
