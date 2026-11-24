class_name MapData
extends Resource
## A map as data: its name, its level scene (where everything spawns: player starts, free-for-
## all respawns, enemy spawn zones, bot points of interest; see Level) and which modes it suits.
## Real values live in levels/data/*.tres; MatchSettings.map picks one. Every level scene must
## also be in Main's LevelSpawner, and pass the map check (tests/levels/test_map_check.gd).

@export var display_name: String = ""
@export var scene: PackedScene
@export var supports_waves: bool = true
@export var supports_gun_game: bool = true
