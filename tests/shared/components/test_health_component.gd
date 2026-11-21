extends GutTest


## Simulates the component running on a client, where health must not change.
class ClientHealthComponent:
	extends HealthComponent

	func _can_modify() -> bool:
		return false


var health: HealthComponent


func before_each() -> void:
	health = HealthComponent.new()
	health.max_health = 100
	add_child_autofree(health)
	watch_signals(health)


func test_starts_at_max_health() -> void:
	assert_eq(health.current_health, 100)


func test_take_damage_reduces_health_and_emits_damaged() -> void:
	health.take_damage(30, 2)
	assert_eq(health.current_health, 70)
	assert_signal_emitted_with_parameters(health, "damaged", [30, 2])
	assert_signal_not_emitted(health, "died")


func test_lethal_damage_clamps_to_zero_and_emits_died_once() -> void:
	health.take_damage(250, 5)
	health.take_damage(10, 5)
	assert_eq(health.current_health, 0)
	assert_true(health.is_dead())
	assert_signal_emitted_with_parameters(health, "damaged", [100, 5])
	assert_signal_emit_count(health, "died", 1)
	assert_signal_emitted_with_parameters(health, "died", [5])


func test_zero_or_negative_damage_is_ignored() -> void:
	health.take_damage(0)
	health.take_damage(-20)
	assert_eq(health.current_health, 100)
	assert_signal_not_emitted(health, "damaged")


func test_heal_restores_up_to_max_and_reports_amount() -> void:
	health.take_damage(30)
	health.heal(50)
	assert_eq(health.current_health, 100)
	assert_signal_emitted_with_parameters(health, "healed", [30])


func test_heal_at_full_health_emits_nothing() -> void:
	health.heal(10)
	assert_signal_not_emitted(health, "healed")


func test_dead_cannot_be_healed() -> void:
	health.take_damage(100)
	health.heal(50)
	assert_eq(health.current_health, 0)


func test_reset_restores_full_health() -> void:
	health.take_damage(100)
	health.reset()
	assert_eq(health.current_health, 100)
	assert_false(health.is_dead())


func test_client_cannot_change_health() -> void:
	var client_health := ClientHealthComponent.new()
	client_health.max_health = 50
	add_child_autofree(client_health)
	client_health.current_health = 30
	watch_signals(client_health)
	client_health.take_damage(20)
	client_health.heal(5)
	client_health.reset()
	assert_eq(client_health.current_health, 30)
	assert_signal_not_emitted(client_health, "damaged")
	assert_signal_not_emitted(client_health, "healed")


func test_apply_replicated_shows_host_value_clamped() -> void:
	health.apply_replicated(40)
	assert_eq(health.current_health, 40)
	health.apply_replicated(500)
	assert_eq(health.current_health, 100)
	assert_signal_not_emitted(health, "damaged")
