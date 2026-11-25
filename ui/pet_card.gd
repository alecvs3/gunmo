class_name PetCard
extends Button
## One pet in the Pets menu's list: its portrait, name and role, with gold pips for the tiers
## you own. The pet you own gets a gold frame, the one you're looking at a light frame.

const OWNED_BORDER := Color(1, 0.85, 0.35, 0.9)
const SELECTED_BORDER := Color(1, 1, 1, 0.55)

var pet: PetData

var _portrait := PetPortrait.new()
var _name := Label.new()
var _role := Label.new()


func _init(shown_pet: PetData) -> void:
	pet = shown_pet
	custom_minimum_size = Vector2(190, 96)
	focus_mode = Control.FOCUS_NONE
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	_portrait.custom_minimum_size = Vector2(80, 80)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.pet = pet
	row.add_child(_portrait)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	_name.text = pet.display_name
	_name.add_theme_font_size_override("font_size", 18)
	text.add_child(_name)
	_role.text = pet.role
	_role.add_theme_color_override("font_color", pet.color)
	text.add_child(_role)


## `owned_tier` = tiers you own of this pet (0 = not yours).
func show_state(owned_tier: int, selected: bool) -> void:
	_portrait.tier = owned_tier
	var border: Color = Color(1, 1, 1, 0.08)
	if owned_tier > 0:
		border = OWNED_BORDER
	elif selected:
		border = SELECTED_BORDER
	var fill: Color = Color(pet.color, 0.16 if selected else 0.06)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var boost: float = 0.06 if state == "hover" else 0.0
		add_theme_stylebox_override(state, HudMenu.box(Color(fill, fill.a + boost), border, 2))
