class_name AimLine
extends Node2D
## Looks only, on every peer: where a locked wind-up volley's shot will go, drawn from its muzzle
## until it leaves (its fire_tick on the shared clock), then gone. ProjectileSystem adds one per
## scheduled shot (LatencyPolicy.schedule_windup_shots).

@export var color := Color(1.0, 0.3, 0.25, 0.45)
@export_range(0.5, 8.0) var width: float = 2.0
## The line is the shot's path, but never longer than this (px).
@export_range(50.0, 2000.0) var max_length: float = 520.0

var _fire_tick: float = 0.0
var _end: Vector2 = Vector2.ZERO


func setup(shot: Shot) -> void:
	_fire_tick = shot.fire_tick
	position = shot.origin
	var length: float = minf(shot.speed * shot.lifetime, max_length)
	_end = shot.direction.normalized() * length


func _process(_delta: float) -> void:
	if NetworkManager.clock.server_tick_now() >= _fire_tick:
		queue_free()


func _draw() -> void:
	draw_line(Vector2.ZERO, _end, color, width, true)
