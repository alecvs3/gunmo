class_name ShopWeaponCard
extends Button
## One gun in the shop: its picture, name and price. Pressing it only asks to buy; the host
## decides. The gun you hold gets a frame, guns you can't buy are dimmed.

const DIMMED: Color = Color(1, 1, 1, 0.45)
const POP_SCALE: float = 1.12
const POP_SECONDS: float = 0.3

@onready var _picture: ShopGunPicture = %Picture
@onready var _name_label: Label = %NameLabel
@onready var _price_label: Label = %PriceLabel
@onready var _equipped_frame: Panel = %EquippedFrame


## The line under the gun's name.
static func price_text(weapon: WeaponData, equipped: bool) -> String:
	if equipped:
		return "Equipped"
	if weapon.price == 0:
		return "Free"
	return "%d" % weapon.price


## The gun's picture and name (these never change).
func show_weapon(weapon: WeaponData) -> void:
	_picture.model = weapon.held_model
	_name_label.text = weapon.display_name
	_price_label.text = price_text(weapon, false)


func show_state(weapon: WeaponData, equipped: bool, can_buy: bool) -> void:
	_price_label.text = price_text(weapon, equipped)
	_equipped_frame.visible = equipped
	disabled = not can_buy
	modulate = Color.WHITE if can_buy or equipped else DIMMED


## A purchase the host confirmed: the card swells and settles.
func pop() -> void:
	pivot_offset = size / 2.0
	scale = Vector2.ONE * POP_SCALE
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK)
