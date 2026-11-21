class_name WeaponData
extends Resource
## Tuning for one weapon. Real values live in weapons/data/*.tres.

@export var display_name: String = ""
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
