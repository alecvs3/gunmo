class_name PetTierRow
extends PanelContainer
## One tier on the selected pet's ladder: a numbered badge, the ability's name and what it
## does, and whether you own it, it's next (with its price), or it's still locked.

enum State { OWNED, NEXT, LOCKED }

const NUMERALS: Array[String] = ["I", "II", "III", "IV", "V"]
const GOLD := Color(1, 0.85, 0.35, 1)
const POP_SECONDS: float = 0.35

var _badge := Label.new()
var _title := Label.new()
var _text := Label.new()
var _status := Label.new()


## The status column: "Owned", the price, or "Locked".
static func status_text(state: State, price: int) -> String:
	match state:
		State.OWNED:
			return "Owned"
		State.NEXT:
			return "%d" % price
	return "Locked"


## Which state tier `index` (0-based) is in when you own `owned` tiers of the pet.
static func state_for(index: int, owned: int) -> State:
	if index < owned:
		return State.OWNED
	return State.NEXT if index == owned else State.LOCKED


func _init() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_badge.custom_minimum_size = Vector2(36, 36)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override("font_size", 16)
	row.add_child(_badge)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_title.add_theme_font_size_override("font_size", 16)
	words.add_child(_title)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_color_override("font_color", Color(0.78, 0.8, 0.84))
	_text.add_theme_font_size_override("font_size", 13)
	words.add_child(_text)
	_status.custom_minimum_size = Vector2(70, 0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_status)


func show_tier(pet: PetData, index: int, owned: int) -> void:
	var tier: PetTier = pet.tiers[index]
	var state: State = state_for(index, owned)
	_badge.text = NUMERALS[index]
	_title.text = tier.display_name
	_text.text = tier.description
	_status.text = status_text(state, tier.price)
	_status.add_theme_color_override("font_color", GOLD if state != State.LOCKED else Color.GRAY)
	_badge.add_theme_stylebox_override(
		"normal",
		HudMenu.box(pet.color if state == State.OWNED else Color(0.2, 0.22, 0.26), pet.color, 1, 18)
	)
	_badge.add_theme_color_override(
		"font_color", Color(0.05, 0.05, 0.07) if state == State.OWNED else Color.WHITE
	)
	var border: Color = GOLD if state == State.NEXT else Color(1, 1, 1, 0.06)
	add_theme_stylebox_override("panel", HudMenu.box(Color(0.12, 0.13, 0.16, 0.9), border, 1))
	modulate = Color(1, 1, 1, 0.55) if state == State.LOCKED else Color.WHITE


## A tier the host just confirmed: the row flashes gold and settles.
func pop() -> void:
	modulate = Color(1.6, 1.4, 0.8)
	create_tween().tween_property(self, "modulate", Color.WHITE, POP_SECONDS)
