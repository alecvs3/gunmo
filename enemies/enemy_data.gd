class_name EnemyData
extends Resource
## Tuning for one enemy type. Real values live in enemies/data/*.tres; one scene
## (enemies/chaser.tscn) plays any of them. What it does is a combination of parts: a movement
## behaviour (where it walks) and an attack behaviour (how it hurts players).

## What it does in a wave; the schedule gives each role a share of the budget.
enum Role { FRONTLINE, RANGED, SWARM, SUPPORT }

@export var display_name: String = ""
@export var role: Role = Role.FRONTLINE
## Tint on the sprite (white = the picture's own colors).
@export var color: Color = Color.WHITE
## Drawn size (1 = the picture's size); looks only, the hitbox stays the same.
@export_range(0.1, 4.0) var visual_scale: float = 1.0
## Extra shapes drawn on its sprite (horns...) so its type reads at a glance (enemies/looks/).
@export var look: EnemyLook
## Size of its hitbox, touch area and body (1 = a normal enemy's 32 px); bosses are bigger.
@export_range(0.5, 4.0) var body_scale: float = 1.0
@export_range(1, 100000) var max_health: int = 1
## Damage of every type it takes is multiplied by this (0.75 = 25% less): a boss's thick hide.
## Armor that a damage type can beat is a trait instead. Stacks with wave modifiers.
@export_range(0.05, 2.0) var damage_taken: float = 1.0
## What it is (Armored, Swarm...): each trait takes more or less of each damage type
## (enemies/data/traits/). The wave's modifiers can add more (WaveModifier.adds_traits).
@export var traits: Array[EnemyTrait] = []
## Healing it receives (support pulses, Regenerating waves) is multiplied by this. Those heal
## a share of max health, so bosses take far less, or a boss would out-heal the players.
@export_range(0.0, 1.0) var heal_received: float = 1.0
## Pixels per second.
@export_range(0.0, 2000.0) var move_speed: float = 1.0
## Seconds between path updates towards its target (lower = reacts sooner, costs more).
@export_range(0.05, 5.0) var repath_interval: float = 1.0

@export_group("Behaviours")
## Where it walks (ChaseMovement...). Shared .tres files live in enemies/behaviours/data/.
@export var movement: EnemyMovement
## How it attacks (MeleeAttack...), usually its own sub-resource with this type's numbers.
@export var attack: EnemyAttack
## A shield in front that blocks every hit from there (EnemyShield); none = no shield.
@export var shield: EnemyShield
## Dies into `split_count` enemies of this type (none = it just dies). They spawn where it fell
## with the wave's modifiers and count as enemies of the wave until killed.
@export var split_into: EnemyData
@export_range(0, 8) var split_count: int = 0

@export_group("Boss")
## A boss: its phases, first one first (BossPhase). While a phase is active its movement,
## attack and speed replace the ones above. Empty = not a boss.
@export var phases: Array[BossPhase] = []
## Killing it ends the wave at once (the rest of the wave dies with it): the final boss.
@export var ends_wave_on_death: bool = false

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
## First wave it can appear in.
@export_range(1, 255) var first_wave: int = 1
## How often it is picked compared with the other affordable types.
@export_range(0.0, 100.0) var spawn_weight: float = 1.0
## Added and spawned this many at a time, together (swarms).
@export_range(1, 12) var group_size: int = 1
## Credits for the player who kills it.
@export_range(0, 100000) var bounty: int = 0


func is_boss() -> bool:
	return not phases.is_empty()


## Pure: damage of `type` (a DamageType.Type) it takes is multiplied by this, before modifiers.
func taken(type: int) -> float:
	return damage_taken * EnemyTrait.product(traits, type)


## Pure: the points it really gets back from `amount` points of healing (see heal_received).
func received_heal(amount: int) -> int:
	return roundi(amount * heal_received)


## The movement, attack and speed multiplier of phase `index` (or the plain ones, not a boss).
func movement_in(index: int) -> EnemyMovement:
	if index < phases.size() and phases[index].movement != null:
		return phases[index].movement
	return movement


func attack_in(index: int) -> EnemyAttack:
	if index < phases.size() and phases[index].attack != null:
		return phases[index].attack
	return attack


func speed_in(index: int) -> float:
	return phases[index].speed_multiplier if index < phases.size() else 1.0
