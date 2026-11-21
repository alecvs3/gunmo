extends SceneTree
## Measures how smoothly the view moves in a real window (not headless).
## Hosts a game, walks the player right at full speed, and records every rendered frame:
##   on screen    how far the world actually scrolled on screen (viewport canvas transform)
##   tick steps   the body's raw physics position (what a tick-driven camera would follow)
## Samples are taken after each frame is drawn. With V-Sync the screen shows frames at a fixed
## interval, so for a smooth picture the view must move the same distance every frame: the
## report gives the spread of those per-frame steps (lower = smoother) and the share of frames
## where the view did not move at all (each one is a visible judder on a fast screen).
## Run: godot --path . -s res://tests/visual/frame_pacing.gd
## Like the smoke test it runs before the autoloads exist, so it names no project classes.

const WARM_UP_SECONDS: float = 0.8
const MEASURE_SECONDS: float = 2.0

var _camera_steps: Array[float] = []
var _body_steps: Array[float] = []
var _frame_seconds: Array[float] = []
var _max_screen_offset: float = 0.0


func _initialize() -> void:
	root.add_child(load("res://main.tscn").instantiate())
	_run.call_deferred()


func _run() -> void:
	var network: Node = root.get_node("NetworkManager")
	network.host(7799)
	await create_timer(0.5).timeout
	var player: Node2D = root.get_node("Main/LevelContainer/TestArena/Players/1")
	var command: RefCounted = load("res://shared/network/input_command.gd").new()
	command.move = Vector2.RIGHT
	player.get_node("PlayerInputSource").scripted = command
	await create_timer(WARM_UP_SECONDS).timeout
	await _record(player, player.get_node("PlayerCamera"))
	_report()
	quit()


func _record(body: Node2D, camera: Node2D) -> void:
	var last_camera: Vector2 = -root.get_canvas_transform().origin
	var last_body: Vector2 = body.global_position
	var last_time: int = Time.get_ticks_usec()
	var elapsed: float = 0.0
	while elapsed < MEASURE_SECONDS:
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		var seconds: float = (now - last_time) / 1000000.0
		_frame_seconds.append(seconds)
		var scroll: Vector2 = -root.get_canvas_transform().origin
		_camera_steps.append(scroll.distance_to(last_camera))
		_body_steps.append(body.global_position.distance_to(last_body))
		var drawn: Vector2 = camera.call("drawn_position")
		_max_screen_offset = maxf(_max_screen_offset, drawn.distance_to(camera.global_position))
		last_camera = scroll
		last_body = body.global_position
		last_time = now
		elapsed += seconds


func _report() -> void:
	var fps: float = _frame_seconds.size() / MEASURE_SECONDS
	print(
		(
			"FRAME PACING %d frames in %.1f s (%.0f FPS)"
			% [_frame_seconds.size(), MEASURE_SECONDS, fps]
		)
	)
	print("FRAME PACING on screen:   %s" % _describe(_camera_steps))
	print("FRAME PACING tick steps: %s" % _describe(_body_steps))
	print("FRAME PACING player drift on screen: max %.3f px" % _max_screen_offset)


func _describe(steps: Array[float]) -> String:
	var still_frames: int = 0
	var mean: float = 0.0
	for step in steps:
		mean += step / steps.size()
		if step < 0.001:
			still_frames += 1
	var variance: float = 0.0
	for step in steps:
		variance += pow(step - mean, 2) / steps.size()
	var spread: float = sqrt(variance) / maxf(mean, 0.0001) * 100.0
	var still_share: float = 100.0 * still_frames / steps.size()
	var speed: float = mean * steps.size() / MEASURE_SECONDS
	return (
		"%.0f px/s, %.2f px per frame, step spread %.0f%%, frames without movement %.0f%%"
		% [speed, mean, spread, still_share]
	)
