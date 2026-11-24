class_name Groups
extends RefCounted
## Scene-tree group names shared across systems.

## Players that are alive and can be targeted (enemies and, later, bots read this).
const LIVING_PLAYERS: StringName = &"living_players"
## Every enemy in the level (support enemies look for wounded ones here).
const ENEMIES: StringName = &"enemies"
## Bosses, on every peer (the HUD's boss bar reads them).
const BOSSES: StringName = &"bosses"
## Every player character, alive or not, on every peer (the HUD and spectating read this).
const PLAYERS: StringName = &"players"
