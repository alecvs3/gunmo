class_name WeaponData
extends Resource
## Tuning for one weapon. Real values live in weapons/data/*.tres.

enum Pose { GUN, MACHINE, SILENCER }
## What flies out of it, so every peer draws the same thing (the value travels with each shot).
## Append new kinds at the end: the number is sent with every shot.
enum Projectile { BULLET, ROCKET, PELLET, RIFLE_ROUND }

@export var display_name: String = ""
## How the character holds it (one picture per pose in each CharacterLook), so other players
## can tell which weapon you carry.
@export var pose: Pose = Pose.GUN
## Shop price in credits (0 = free).
@export_range(0, 100000) var price: int = 0
## Bullets per shot (shotgun pellets); each gets its own random spread.
@export_range(1, 16) var pellets: int = 1
## Extra enemies one bullet passes through before it stops.
@export_range(0, 16) var pierce: int = 0
@export_range(0, 1000) var damage: int = 1
## Shots per second.
@export_range(0.1, 60.0) var fire_rate: float = 1.0
## Pixels per second.
@export_range(1.0, 5000.0) var bullet_speed: float = 100.0
## Seconds a bullet flies before it disappears.
@export_range(0.05, 10.0) var bullet_lifetime: float = 1.0
## Total cone width in degrees.
@export_range(0.0, 90.0) var spread: float = 0.0
@export_range(1, 500) var magazine_size: int = 1
## Seconds.
@export_range(0.0, 10.0) var reload_time: float = 1.0
## Bullet size for hit tests (px).
@export_range(0.0, 64.0) var bullet_radius: float = 4.0
## Push given to whatever the bullet hits (px/s along the bullet's path).
@export_range(0.0, 3000.0) var knockback: float = 0.0

@export_group("Per upgrade level")
## What one level of each gun upgrade adds to this gun (shop upgrades on DAMAGE, FIRE_RATE,
## MAGAZINE, RELOAD_SPEED and KNOCKBACK). Every gun sets its own, so every level does
## something that fits it: a rocket launcher gets +1 rocket, an SMG +6 rounds.
@export_range(0, 1000) var damage_per_level: int = 0
## Added to blast_damage per DAMAGE level (exploding guns).
@export_range(0, 1000) var blast_damage_per_level: int = 0
## Shots per second.
@export_range(0.0, 10.0) var fire_rate_per_level: float = 0.0
@export_range(0, 100) var magazine_per_level: int = 0
## Seconds taken off the reload.
@export_range(0.0, 5.0) var reload_per_level: float = 0.0
@export_range(0.0, 1000.0) var knockback_per_level: float = 0.0

@export_group("Looks")
## Drawn over the character's hands, its front end at the muzzle, covering the gun painted into
## the character picture (weapons/models/). None = the picture's own gun.
@export var held_model: PackedScene
@export var projectile: Projectile = Projectile.BULLET

@export_group("Explosion")
## Where the shot lands (a hit, a wall or the end of its range), everyone else within this
## radius (px) takes blast_damage and is pushed away. 0 = no explosion.
@export_range(0.0, 1000.0) var blast_radius: float = 0.0
@export_range(0, 1000) var blast_damage: int = 0


func explodes() -> bool:
	return blast_radius > 0.0 and blast_damage > 0
