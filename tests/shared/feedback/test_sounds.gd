extends GutTest
## The sound picks load, every cue and every shop gun has something to play, and the per-cue
## cap works.


func test_every_cue_has_a_sound() -> void:
	var sounds: SoundData = SoundData.load_default()
	assert_null(sounds.enemy_hit, "hits are silent for now")
	assert_null(sounds.enemy_big_hit, "big hits too")
	var cues: Array[SoundCue] = [
		sounds.enemy_death,
		sounds.boss_death,
		sounds.blast,
		sounds.player_hurt,
		sounds.click,
		sounds.shop_open,
		sounds.shop_close,
		sounds.bought,
		sounds.banner,
	]
	for cue in cues:
		assert_not_null(cue, "a cue is missing")
		if cue == null:
			continue
		var randomizer := cue.stream as AudioStreamRandomizer
		assert_not_null(randomizer, "cues pick a random variant")
		if randomizer == null:
			continue
		assert_gt(randomizer.streams_count, 0)
		for i in randomizer.streams_count:
			assert_not_null(randomizer.get_stream(i), "variant %d loads" % i)


func test_cap_per_cue() -> void:
	var cue := SoundCue.new()
	cue.max_at_once = 2
	assert_false(SoundPlayback.has_room(cue, 0), "nothing to play without a stream")
	cue.stream = AudioStreamRandomizer.new()
	assert_true(SoundPlayback.has_room(cue, 1))
	assert_false(SoundPlayback.has_room(cue, 2))
	assert_false(SoundPlayback.has_room(null, 0))


func test_the_blast_sounds_deeper_than_the_rocket_launch() -> void:
	var blast: SoundCue = SoundData.load_default().blast
	var launch: SoundCue = load("res://shared/feedback/data/guns/rocket_launch.tres")
	assert_lt(blast.pitch_scale, launch.pitch_scale, "the blast must not sound like a second shot")


func test_every_shop_gun_has_a_fire_sound() -> void:
	for weapon in ShopCatalog.load_default().weapons:
		var cue: SoundCue = weapon.fire_sound
		assert_not_null(cue, weapon.display_name + " has a fire sound")
		if cue != null:
			var randomizer := cue.stream as AudioStreamRandomizer
			assert_not_null(randomizer, weapon.display_name)
			if randomizer != null:
				for i in randomizer.streams_count:
					assert_not_null(
						randomizer.get_stream(i), "%s variant %d" % [weapon.display_name, i]
					)
