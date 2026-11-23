class_name EnemyData
extends Resource
## Tuning for one enemy type. Real values live in enemies/data/*.tres; one scene
## (enemies/chaser.tscn) plays any of them. What it does is a combination of parts: a movement
## behaviour (where it walks) and an attack behaviour (how it hurts players).

@export var display_name: String = ""
## Tint on the sprite (white = the picture's own colors).
@export var color: Color = Color.WHITE
## Drawn size (1 = the picture's size); looks only, the hitbox stays the same.
@export_range(0.1, 4.0) var visual_scale: float = 1.0
@export_range(1, 100000) var max_health: int = 1
## Armor: damage it takes is multiplied by this (0.7 = 30% less). Stacks with wave modifiers.
@export_range(0.05, 2.0) var damage_taken: float = 1.0
## Pixels per second.
@export_range(0.0, 2000.0) var move_speed: float = 1.0
## Seconds between path updates towards its target (lower = reacts sooner, costs more).
@export_range(0.05, 5.0) var repath_interval: float = 1.0

@export_group("Behaviours")
## Where it walks (ChaseMovement...). Shared .tres files live in enemies/behaviours/data/.
@export var movement: EnemyMovement
## How it attacks (MeleeAttack...), usually its own sub-resource with this type's numbers.
@export var attack: EnemyAttack

@export_group("Knockback")
## How fast a push on this enemy dies down (px/s lost per second).
@export_range(0.0, 20000.0) var knockback_friction: float = 2000.0
## Share of a push kept when it drives the enemy into a wall (0..1).
@export_range(0.0, 1.0) var knockback_bounce: float = 0.3
## Multiplier on pushes received (0 = immovable; heavy or "armored" enemies use less).
@export_range(0.0, 5.0) var knockback_taken: float = 1.0

@export_group("Flinch")
## How far a hit twists it towards the way it was pushed (degrees; 0 = no flinch). Looks only.
@export_range(0.0, 90.0) var flinch_degrees: float = 25.0
## Seconds it takes to turn back to where it is walking after a flinch.
@export_range(0.01, 2.0) var flinch_recovery: float = 0.25

@export_group("Waves")
## Wave budget points this enemy costs.
@export_range(0.1, 100.0) var cost: float = 1.0
## First wave it can appear in.
@export_range(1, 255) var first_wave: int = 1
## How often it is picked compared with the other affordable types.
@export_range(0.0, 100.0) var spawn_weight: float = 1.0
## Bought and spawned this many at a time, together (swarms). Each one costs `cost`.
@export_range(1, 12) var group_size: int = 1
## Credits for the player who kills it.
@export_range(0, 100000) var bounty: int = 0
