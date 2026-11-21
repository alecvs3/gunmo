class_name PlayerLook
extends Sprite2D
## The player's character picture. It sits under the aim pivot so it turns with the aim, and
## shows the pose of the weapon held, plus the weapon's held model if it has one (a launcher
## tube), placed with its front end at the muzzle. Looks only: every peer picks the same
## character from the peer id, so nothing extra is sent over the network.

## Muzzle used when no character is set (straight ahead of the body).
const NO_CHARACTER_MUZZLE: Vector2 = Vector2(30, 0)

var character: CharacterLook:
	set(value):
		character = value
		_refresh()
var pose: WeaponData.Pose = WeaponData.Pose.GUN:
	set(value):
		pose = value
		_refresh()
## WeaponData.held_model of the weapon held (null = none).
var held_model: PackedScene:
	set(value):
		if value != held_model:
			held_model = value
			_replace_model()

var _model: Node2D


## Where the barrel ends for `weapon_pose`, in the pivot's space (facing right).
func muzzle_for(weapon_pose: WeaponData.Pose) -> Vector2:
	return character.muzzle_for(weapon_pose) if character != null else NO_CHARACTER_MUZZLE


func _refresh() -> void:
	texture = character.texture_for(pose) if character != null else null
	if _model != null:
		_model.position = muzzle_for(pose)


func _replace_model() -> void:
	if _model != null:
		_model.queue_free()
		_model = null
	if held_model != null:
		_model = held_model.instantiate() as Node2D
		add_child(_model)
	_refresh()
