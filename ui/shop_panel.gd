class_name ShopPanel
extends PanelContainer
## The shop: shown while the match says it is open (Waves: the lobby and between waves);
## B hides or shows it.
## Buttons only *ask* to buy (EventBus.shop_purchase_requested); the host checks and applies.
## Credits, levels and the equipped weapon come from your own player's replicated state.
## Perks (upgrades with HitEffects) get their own list, with how many slots are used.

var _catalog: ShopCatalog = ShopCatalog.load_default()
var _phase: int = -1
var _open: bool = false
var _hidden_by_player: bool = false
var _weapon_buttons: Array[Button] = []
var _upgrade_buttons: Array[Button] = []

@onready var _credits_label: Label = %ShopCredits
@onready var _weapons_box: VBoxContainer = %Weapons
@onready var _upgrades_box: VBoxContainer = %Upgrades
@onready var _perks_box: VBoxContainer = %Perks
@onready var _perks_title: Label = %PerksTitle


static func weapon_label(weapon: WeaponData, equipped: bool) -> String:
	if equipped:
		return "%s (equipped)" % weapon.display_name
	if weapon.price == 0:
		return "%s · free" % weapon.display_name
	return "%s · %d" % [weapon.display_name, weapon.price]


static func perks_title(owned: int, slots: int) -> String:
	return "Perks: your build (%d of %d chosen)" % [owned, slots]


static func upgrade_label(upgrade: UpgradeData, level: int) -> String:
	if level >= upgrade.max_level:
		return "%s %d/%d (max)" % [upgrade.display_name, level, upgrade.max_level]
	return "%s %d/%d · %d" % [upgrade.display_name, level, upgrade.max_level, upgrade.cost(level)]


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
		var upgrade: UpgradeData = _catalog.upgrades[i]
		var box: VBoxContainer = _perks_box if upgrade.is_perk() else _upgrades_box
		_upgrade_buttons.append(_add_button(box, ShopRules.KIND_UPGRADE, i, upgrade.description))


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
	var perks: int = PlayerStats.perks_owned(_catalog, loadout.levels)
	_perks_title.text = perks_title(perks, _catalog.max_perks)
	for i in _upgrade_buttons.size():
		var level: int = loadout.level(i)
		_upgrade_buttons[i].text = upgrade_label(_catalog.upgrades[i], level)
		var problem: String = ShopRules.check_upgrade(true, _catalog, i, level, credits, perks)
		_upgrade_buttons[i].disabled = not problem.is_empty()
		var tip: String = _catalog.upgrades[i].description
		if not problem.is_empty() and problem != "Not enough credits.":
			tip += "\n" + problem
		_upgrade_buttons[i].tooltip_text = tip
