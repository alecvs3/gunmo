class_name ShopPanel
extends PanelContainer
## The shop: shown while the match says it is open (Waves: the lobby and between waves);
## B hides or shows it.
## Buttons only *ask* to buy (EventBus.shop_purchase_requested); the host checks and applies.
## Credits, levels and the equipped weapon come from your own player's replicated state.

var _catalog: ShopCatalog = ShopCatalog.load_default()
var _phase: int = -1
var _open: bool = false
var _hidden_by_player: bool = false
var _weapon_buttons: Array[Button] = []
var _upgrade_buttons: Array[Button] = []

@onready var _credits_label: Label = %ShopCredits
@onready var _weapons_box: VBoxContainer = %Weapons
@onready var _upgrades_box: VBoxContainer = %Upgrades


static func weapon_label(weapon: WeaponData, equipped: bool) -> String:
	if equipped:
		return "%s (equipped)" % weapon.display_name
	if weapon.price == 0:
		return "%s · free" % weapon.display_name
	return "%s · %d" % [weapon.display_name, weapon.price]


## "Magazine 2/5 · +1 ammo · 150": what the next level gives `weapon` (the gun held) and its
## price.
static func upgrade_label(upgrade: UpgradeData, level: int, weapon: WeaponData) -> String:
	if level >= upgrade.max_level:
		return "%s %d/%d (max)" % [upgrade.display_name, level, upgrade.max_level]
	return (
		"%s %d/%d · %s · %d"
		% [
			upgrade.display_name,
			level,
			upgrade.max_level,
			gain_text(upgrade, weapon),
			upgrade.cost(level),
		]
	)


## What one more level of `upgrade` adds, for `weapon` when it is a gun stat.
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


func _ready() -> void:
	hide()
	_build_buttons()
	EventBus.match_state_changed.connect(_on_match_state_changed)
	NetworkManager.session_ended.connect(_on_session_ended.unbind(1))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shop") and _open:
		_hidden_by_player = not _hidden_by_player
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var player: Player = Player.find_local(get_tree())
	visible = NetworkManager.is_online() and _open and not _hidden_by_player
	if visible and player != null:
		_refresh(player)


func _build_buttons() -> void:
	for i in _catalog.weapons.size():
		_weapon_buttons.append(_add_button(_weapons_box, ShopRules.KIND_WEAPON, i, ""))
	for i in mini(_catalog.upgrades.size(), ShopCatalog.MAX_UPGRADES):
		var tip: String = _catalog.upgrades[i].description
		_upgrade_buttons.append(_add_button(_upgrades_box, ShopRules.KIND_UPGRADE, i, tip))


func _add_button(box: VBoxContainer, kind: int, index: int, tip: String) -> Button:
	var button := Button.new()
	button.tooltip_text = tip
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(EventBus.shop_purchase_requested.emit.bind(kind, index))
	box.add_child(button)
	return button


## A new lobby or break opens the shop again, even if it was hidden last time.
func _on_match_state_changed(state: RefCounted) -> void:
	var match_state := state as MatchNetState
	_open = match_state.shop_open
	if match_state.phase != _phase:
		_phase = match_state.phase
		_hidden_by_player = false


func _on_session_ended() -> void:
	_phase = -1
	_open = false


func _refresh(player: Player) -> void:
	var loadout: PlayerLoadout = player.get_loadout()
	var credits: int = player.get_wallet().credits
	_credits_label.text = "%d credits" % credits
	for i in _weapon_buttons.size():
		var equipped: bool = i == loadout.weapon_index
		_weapon_buttons[i].text = weapon_label(_catalog.weapons[i], equipped)
		var problem: String = ShopRules.check_weapon(
			true, _catalog, i, loadout.weapon_index, credits
		)
		_weapon_buttons[i].disabled = not problem.is_empty()
	for i in _upgrade_buttons.size():
		var level: int = loadout.level(i)
		var held: WeaponData = _catalog.weapon(loadout.weapon_index)
		_upgrade_buttons[i].text = upgrade_label(_catalog.upgrades[i], level, held)
		var problem: String = ShopRules.check_upgrade(true, _catalog, i, level, credits)
		_upgrade_buttons[i].disabled = not problem.is_empty()
