class_name SoundPlayback
extends Node
## Plays SoundCues: `play_at` in the world (louder and centred when near the camera), `play`
## for interface sounds. Each play gets its own short-lived player, at most `max_at_once` per
## cue. Silent on a headless peer (dedicated server, tests).

## Cue -> how many of it are playing now.
var _playing: Dictionary[SoundCue, int] = {}


## Whether one more of `cue` may start while `playing` already are.
static func has_room(cue: SoundCue, playing: int) -> bool:
	return cue != null and cue.stream != null and playing < cue.max_at_once


static func is_silent() -> bool:
	return DisplayServer.get_name() == "headless"


func play_at(cue: SoundCue, at: Vector2) -> void:
	if is_silent() or not has_room(cue, _playing.get(cue, 0)) or not at.is_finite():
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = cue.stream
	player.volume_db = cue.volume_db
	player.max_distance = cue.max_distance
	player.position = at  # the parent is a plain Node, so this is a world position
	add_child(player)
	_track(player.finished, player, cue)
	player.play()


func play(cue: SoundCue) -> void:
	if is_silent() or not has_room(cue, _playing.get(cue, 0)):
		return
	var player := AudioStreamPlayer.new()
	player.stream = cue.stream
	player.volume_db = cue.volume_db
	add_child(player)
	_track(player.finished, player, cue)
	player.play()


func _track(finished: Signal, player: Node, cue: SoundCue) -> void:
	_playing[cue] = _playing.get(cue, 0) + 1
	finished.connect(_on_finished.bind(player, cue))


func _on_finished(player: Node, cue: SoundCue) -> void:
	_playing[cue] = maxi(_playing.get(cue, 1) - 1, 0)
	player.queue_free()
