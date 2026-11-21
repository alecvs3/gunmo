class_name PlayerLook
extends Sprite2D
## The player's character picture. It sits under the aim pivot so it turns with the aim, and
## shows the pose of the weapon held. Looks only: every peer picks the same character from the
## peer id, so nothing extra is sent over the network.

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


## Where the barrel ends for `weapon_pose`, in the pivot's space (facing right).
func muzzle_for(weapon_pose: WeaponData.Pose) -> Vector2:
	return character.muzzle_for(weapon_pose) if character != null else NO_CHARACTER_MUZZLE


func _refresh() -> void:
	texture = character.texture_for(pose) if character != null else null
