class_name SoundData
extends Resource
## Which sound plays for each moment, and how loud. Sounds only: nothing here changes gameplay.
## A cue left empty is silent (enemy hits, normal and big, are for now: nothing fit yet).

const DEFAULT_PATH: String = "res://shared/feedback/data/default_sounds.tres"

@export_group("World")
@export var enemy_hit: SoundCue
@export var enemy_big_hit: SoundCue
@export var enemy_death: SoundCue
## Bosses play this instead of enemy_death.
@export var boss_death: SoundCue
@export var blast: SoundCue
@export_group("You")
@export var player_hurt: SoundCue
@export_group("Interface")
@export var click: SoundCue
@export var shop_open: SoundCue
@export var shop_close: SoundCue
@export var bought: SoundCue
@export var banner: SoundCue


static func load_default() -> SoundData:
	return load(DEFAULT_PATH)
