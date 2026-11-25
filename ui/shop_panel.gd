class_name ShopPanel
extends HudMenu
## The shop (B): guns on the left, upgrades for the held gun on the right. Opening, closing and
## the look of the window come from HudMenu.
## Cards and buy buttons only *ask* to buy (EventBus.shop_purchase_requested); the host checks
## and applies. Credits, levels and the equipped weapon come from your own player's replicated
## state, so a card or level dot pops only once the host has confirmed the purchase.

const WEAPON_CARD: PackedScene = preload("res://ui/shop_weapon_card.tscn")
const UPGRADE_ROW: PackedScene = preload("res://ui/shop_upgrade_row.tscn")

var _catalog: ShopCatalog = ShopCatalog.load_default()
var _cards: Array[ShopWeaponCard] = []
var _rows: Array[ShopUpgradeRow] = []
## What the last refresh showed (null = nothing yet, so opening the shop pops nothing).
var _seen: ShopSeen = null

@onready var _credits_label: Label = %ShopCredits
@onready var _weapons_box: Container = %Weapons
@onready var _upgrades_box: VBoxContainer = %Upgrades
@onready var _upgrades_title: Label = %UpgradesTitle


## "+2 dmg": what one more level of `upgrade` adds, for `weapon` when it is a gun stat.
static func gain_text(upgrade: UpgradeData, weapon: WeaponData) -> String:
	match upgrade.stat:
		UpgradeData.Stat.DAMAGE:
			if weapon.blast_damage_per_level > 0:
				return (
					"+%d dmg, +%d blast" % [weapon.damage_per_level, weapon.blast_damage_per_level]
				)
			return "+%d dmg" % weapon.damage_per_level
		UpgradeData.Stat.FIRE_RATE:
			return "+%s shots/s" % String.num(weapon.fire_rate_per_level, 2)
		UpgradeData.Stat.MAGAZINE:
			return "+%d ammo" % weapon.magazine_per_level
		UpgradeData.Stat.RELOAD_SPEED:
			return "-%s s" % String.num(weapon.reload_per_level, 2)
		UpgradeData.Stat.KNOCKBACK:
			return "+%d push" % roundi(weapon.knockback_per_level)
	return "+%d%%" % roundi(upgrade.per_level * 100.0)


func _action() -> StringName:
	return &"shop"


func _hint_text() -> String:
	return "B: Shop"


func _hint_slot() -> int:
	return 0


func _make_window() -> PanelContainer:
	return %Window


## Opening the shop pops nothing until the next confirmed purchase.
func _on_opened(_player: Player) -> void:
	_seen = null


func _build_content(_into: PanelContainer) -> void:
	for weapon in _catalog.weapons:
		var card: ShopWeaponCard = WEAPON_CARD.instantiate()
		_weapons_box.add_child(card)
		card.show_weapon(weapon)
		card.pressed.connect(_request.bind(ShopRules.KIND_WEAPON, _cards.size()))
		_cards.append(card)
	for i in mini(_catalog.upgrades.size(), ShopCatalog.MAX_UPGRADES):
		var row: ShopUpgradeRow = UPGRADE_ROW.instantiate()
		_upgrades_box.add_child(row)
		row.show_upgrade(_catalog.upgrades[i], 0, _catalog.weapon(0), false)
		row.buy_pressed.connect(_request.bind(ShopRules.KIND_UPGRADE, i))
		_rows.append(row)


func _request(kind: int, index: int) -> void:
	_sound.play(_sounds.click)
	EventBus.shop_purchase_requested.emit(kind, index)


func _refresh(player: Player) -> void:
	var loadout: PlayerLoadout = player.get_loadout()
	var credits: int = player.get_wallet().credits
	var held: WeaponData = _catalog.weapon(loadout.weapon_index)
	var now := ShopSeen.from_loadout(loadout, _rows.size())
	_credits_label.text = "%d credits" % credits
	_upgrades_title.text = "Upgrades for your %s" % held.display_name
	for i in _cards.size():
		var equipped: bool = i == loadout.weapon_index
		var problem: String = ShopRules.check_weapon(
			true, _catalog, i, loadout.weapon_index, credits
		)
		_cards[i].show_state(_catalog.weapons[i], equipped, problem.is_empty())
		if _seen != null and _seen.weapon_bought(now) == i:
			_cards[i].pop()
			_sound.play(_sounds.bought)
	var discount: float = loadout.shop_price_multiplier()
	for i in _rows.size():
		var level: int = loadout.level(i)
		var problem: String = ShopRules.check_upgrade(true, _catalog, i, level, credits, discount)
		_rows[i].show_upgrade(_catalog.upgrades[i], level, held, problem.is_empty(), discount)
		if _seen != null and _seen.level_bought(now, i):
			_rows[i].pop()
			_sound.play(_sounds.bought)
	_seen = now
