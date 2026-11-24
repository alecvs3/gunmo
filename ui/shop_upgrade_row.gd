class_name ShopUpgradeRow
extends PanelContainer
## One upgrade in the shop: its name and level dots, what the next level gives the gun held,
## and a buy button with the price. The button only asks; the host decides.

signal buy_pressed

@onready var _name_label: Label = %NameLabel
@onready var _pips: ShopPips = %Pips
@onready var _gain_label: Label = %GainLabel
@onready var _buy_button: Button = %BuyButton


## The buy button's text: the next level's price, or MAX at the cap.
static func buy_text(upgrade: UpgradeData, level: int) -> String:
	if level >= upgrade.max_level:
		return "MAX"
	return "%d" % upgrade.cost(level)


## What the next level gives, or that there is nothing left to buy.
static func gain_line(upgrade: UpgradeData, level: int, weapon: WeaponData) -> String:
	if level >= upgrade.max_level:
		return "Fully upgraded"
	return "Next: %s" % ShopPanel.gain_text(upgrade, weapon)


func _ready() -> void:
	_buy_button.pressed.connect(buy_pressed.emit)


func show_upgrade(upgrade: UpgradeData, level: int, weapon: WeaponData, can_buy: bool) -> void:
	_name_label.text = upgrade.display_name
	tooltip_text = upgrade.description
	_pips.max_level = upgrade.max_level
	_pips.level = level
	_gain_label.text = gain_line(upgrade, level, weapon)
	_buy_button.text = buy_text(upgrade, level)
	_buy_button.disabled = not can_buy


## A purchase the host confirmed: the new dot pops.
func pop() -> void:
	_pips.pop()
