extends GutTest
## HitFeedback with predicted hits: our own hit flashes at once, and the host's health drop for
## it shows its number without a second flash or sound.

var _health: HealthComponent
var _feedback: HitFeedback
var _seen: Array = []


func before_each() -> void:
	_seen.clear()
	_health = HealthComponent.new()
	_health.max_health = 100
	_health.current_health = 100
	add_child_autofree(_health)
	var look := Sprite2D.new()
	add_child_autofree(look)
	_feedback = HitFeedback.new()
	_feedback.health = _health
	_feedback.target = look
	_feedback.show_numbers = true
	add_child_autofree(_feedback)
	_feedback._process(0.0)
	EventBus.damage_seen.connect(_on_damage_seen)


func after_each() -> void:
	EventBus.damage_seen.disconnect(_on_damage_seen)


func test_a_predicted_hit_flashes_at_once() -> void:
	_feedback.flash()
	assert_gt(_feedback._flash_left, 0.0)
	assert_eq(_seen.size(), 0, "the number waits for the host")


func test_the_hosts_drop_for_a_predicted_hit_is_not_shown_twice() -> void:
	_feedback.flash()
	_feedback._flash_left = 0.0
	_lose(10)
	assert_eq(_seen, [[10, true]], "number shown, marked as already heard")
	assert_eq(_feedback._flash_left, 0.0, "no second flash")


func test_a_hit_nobody_predicted_flashes_and_sounds() -> void:
	_lose(10)
	assert_eq(_seen, [[10, false]])
	assert_gt(_feedback._flash_left, 0.0)


func test_one_prediction_covers_one_drop() -> void:
	_feedback.flash()
	_lose(10)
	_lose(10)
	assert_eq(_seen, [[10, true], [10, false]])


func _lose(amount: int) -> void:
	_health.current_health -= amount
	_feedback._process(0.0)


func _on_damage_seen(_at: Vector2, amount: int, _big: bool, predicted: bool) -> void:
	_seen.append([amount, predicted])
