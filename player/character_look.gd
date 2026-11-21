class_name CharacterLook
extends Resource
## How one character is drawn: one picture per weapon pose, facing right (the aim direction).
## The sprite's offset in player.tscn puts the head on the body's center.
## Real looks live in player/looks/*.tres.

@export var display_name: String = ""
@export var gun: Texture2D
@export var machine: Texture2D
@export var silencer: Texture2D

@export_group("Muzzle")
## Where the drawn barrel ends for each pose, from the body's center with the character facing
## right (x forward, y to the gun side). Shots start here, so it must match the picture.
@export var gun_muzzle: Vector2 = Vector2(33, 10)
@export var machine_muzzle: Vector2 = Vector2(33, 10)
@export var silencer_muzzle: Vector2 = Vector2(38, 10)


func texture_for(pose: WeaponData.Pose) -> Texture2D:
	match pose:
		WeaponData.Pose.MACHINE:
			return machine
		WeaponData.Pose.SILENCER:
			return silencer
	return gun


func muzzle_for(pose: WeaponData.Pose) -> Vector2:
	match pose:
		WeaponData.Pose.MACHINE:
			return machine_muzzle
		WeaponData.Pose.SILENCER:
			return silencer_muzzle
	return gun_muzzle
