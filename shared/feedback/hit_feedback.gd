class_name HitFeedback
extends Node
## Looks only, on every peer: watches a HealthComponent and, when it drops, flashes `target`
## white and (if `show_numbers`) asks for a damage number (EventBus.damage_seen). It reads the
## health the host decided (on clients it comes from snapshots), so it never decides anything.
## Healing and respawns (health going up) show nothing.

const FLASH_SHADER: Shader = preload("res://shared/feedback/hit_flash.gdshader")

@export var health: HealthComponent
## What flashes: it gets its own hit_flash shader material, which blends it towards white
## (any tint in its modulate is kept underneath).
@export var target: CanvasItem
@export var show_numbers: bool = false
@export var data: FeedbackData

## Health last frame (-1 = not seen yet).
var _last_health: int = -1
var _flash_left: float = 0.0
var _material := ShaderMaterial.new()


## Health lost since last frame (0 when it rose or stayed, or on the first look).
static func lost(previous: int, current: int) -> int:
	if previous < 0:
		return 0
	return maxi(previous - current, 0)


## How white (0..1) the flash is `left` seconds before it ends, out of `seconds` in total.
static func flash_weight(left: float, seconds: float, amount: float) -> float:
	return amount * clampf(left / maxf(seconds, 0.001), 0.0, 1.0)


func _ready() -> void:
	if data == null:
		data = FeedbackData.load_default()
	_material.shader = FLASH_SHADER
	target.material = _material


func _process(delta: float) -> void:
	var current: int = health.current_health
	var amount: int = lost(_last_health, current)
	_last_health = current
	if amount > 0:
		_on_lost(amount)
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		var weight: float = flash_weight(_flash_left, data.flash_seconds, data.flash_amount)
		_material.set_shader_parameter("flash", weight)


func _on_lost(amount: int) -> void:
	_flash_left = data.flash_seconds
	if show_numbers and target is Node2D:
		var big: bool = data.is_big_hit(amount, health.max_health)
		EventBus.damage_seen.emit((target as Node2D).global_position, amount, big)
