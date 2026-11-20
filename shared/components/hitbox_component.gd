class_name HitboxComponent
extends Area2D
## The area that bullets and contact damage hit. Forwards every hit to a HealthComponent.

@export var health: HealthComponent


func hit(damage: int, source_id: int) -> void:
	if health != null:
		health.take_damage(damage, source_id)
