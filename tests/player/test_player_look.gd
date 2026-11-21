extends GutTest

const DEFAULT_PLAYER: String = "res://player/data/default_player.tres"
## Minus the Look sprite's offset in player.tscn: body center -> picture pixels.
const SPRITE_ORIGIN: Vector2 = Vector2(15, 21.5)


func _look(name: String) -> CharacterLook:
	var look := CharacterLook.new()
	look.display_name = name
	look.gun = PlaceholderTexture2D.new()
	look.machine = PlaceholderTexture2D.new()
	look.silencer = PlaceholderTexture2D.new()
	return look


func test_texture_for_each_pose() -> void:
	var look := _look("a")
	assert_eq(look.texture_for(WeaponData.Pose.GUN), look.gun)
	assert_eq(look.texture_for(WeaponData.Pose.MACHINE), look.machine)
	assert_eq(look.texture_for(WeaponData.Pose.SILENCER), look.silencer)


func test_humans_and_bots_pick_from_their_own_lists() -> void:
	var data := PlayerData.new()
	data.player_looks = [_look("human 0"), _look("human 1")]
	data.bot_looks = [_look("bot 0"), _look("bot 1"), _look("bot 2")]
	assert_eq(data.look_for(1).display_name, "human 1")
	assert_eq(data.look_for(4).display_name, "human 0")
	assert_eq(data.look_for(-1).display_name, "bot 1")
	assert_eq(data.look_for(-3).display_name, "bot 0")


func test_same_peer_always_gets_the_same_look() -> void:
	var data: PlayerData = load(DEFAULT_PLAYER)
	assert_eq(data.look_for(123456789), data.look_for(123456789))


func test_no_looks_gives_no_character() -> void:
	assert_null(PlayerData.new().look_for(1))


func test_sprite_follows_character_and_pose() -> void:
	var sprite := PlayerLook.new()
	add_child_autofree(sprite)
	var look := _look("a")
	sprite.pose = WeaponData.Pose.MACHINE
	assert_null(sprite.texture, "no character yet")
	sprite.character = look
	assert_eq(sprite.texture, look.machine)
	sprite.pose = WeaponData.Pose.SILENCER
	assert_eq(sprite.texture, look.silencer)


func test_default_looks_have_every_pose() -> void:
	var data: PlayerData = load(DEFAULT_PLAYER)
	assert_gt(data.player_looks.size(), 0)
	assert_gt(data.bot_looks.size(), 0)
	for look: CharacterLook in data.player_looks + data.bot_looks:
		for pose: int in WeaponData.Pose.values():
			assert_not_null(look.texture_for(pose), "%s pose %d" % [look.display_name, pose])


func test_muzzle_for_each_pose() -> void:
	var look := _look("a")
	look.gun_muzzle = Vector2(1, 2)
	look.machine_muzzle = Vector2(3, 4)
	look.silencer_muzzle = Vector2(5, 6)
	assert_eq(look.muzzle_for(WeaponData.Pose.GUN), Vector2(1, 2))
	assert_eq(look.muzzle_for(WeaponData.Pose.MACHINE), Vector2(3, 4))
	assert_eq(look.muzzle_for(WeaponData.Pose.SILENCER), Vector2(5, 6))


func test_sprite_muzzle_comes_from_character() -> void:
	var sprite := PlayerLook.new()
	add_child_autofree(sprite)
	assert_eq(sprite.muzzle_for(WeaponData.Pose.GUN), PlayerLook.NO_CHARACTER_MUZZLE)
	var look := _look("a")
	sprite.character = look
	assert_eq(sprite.muzzle_for(WeaponData.Pose.SILENCER), look.silencer_muzzle)


## Shots start at the muzzle, so it must sit on the drawn barrel's tip: the pixel just behind it
## is part of the gun, the pixel just past it is empty.
func test_default_muzzles_sit_on_the_drawn_barrel_tip() -> void:
	var data: PlayerData = load(DEFAULT_PLAYER)
	for look: CharacterLook in data.player_looks + data.bot_looks:
		for pose: int in WeaponData.Pose.values():
			var image: Image = look.texture_for(pose).get_image()
			var tip: Vector2i = Vector2i((look.muzzle_for(pose) + SPRITE_ORIGIN).floor())
			var label: String = "%s pose %d" % [look.display_name, pose]
			assert_gt(image.get_pixelv(tip + Vector2i.LEFT).a, 0.5, label + ": gun behind tip")
			var past: Vector2i = tip + Vector2i.RIGHT
			if past.x < image.get_width():
				assert_lt(image.get_pixelv(past).a, 0.5, label + ": nothing past tip")


func test_barrel_line_passes_through_the_mouse() -> void:
	var muzzle := Vector2(33, 10)
	for target: Vector2 in [Vector2(200, 0), Vector2(-50, 120), Vector2(40, -40)]:
		var aim: float = (
			target.angle() - PlayerInputSource.barrel_correction(muzzle.y, target.length())
		)
		var origin: Vector2 = muzzle.rotated(aim)
		var direction: Vector2 = Vector2.from_angle(aim)
		var miss: float = absf(direction.cross(target - origin))
		assert_almost_eq(miss, 0.0, 0.001, "aim line misses %s by %f" % [target, miss])


func test_held_model_sits_at_the_muzzle_and_is_replaced() -> void:
	var look := PlayerLook.new()
	add_child_autofree(look)
	var character: CharacterLook = _look("a")
	character.machine_muzzle = Vector2(40, 10)
	look.character = character
	look.pose = WeaponData.Pose.MACHINE
	look.held_model = load("res://weapons/models/rocket_launcher_tube.tscn")
	assert_eq(look.get_child_count(), 1)
	var model := look.get_child(0) as Node2D
	assert_eq(model.position, Vector2(40, 10), "the tube's front end is where rockets leave")
	look.held_model = null
	await get_tree().process_frame
	assert_eq(look.get_child_count(), 0, "a plain gun shows no model")
