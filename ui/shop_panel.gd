class_name ShopPanel
extends PanelContainer
## The shop: open in the lobby and between waves, closed during waves; B hides or shows it.
## Buttons only *ask* to buy (EventBus.shop_purchase_requested); the host checks and applies.
## Credits, levels and the equipped weapon come from your own player's replicated state.

var _catalog: ShopCatalog = ShopCatalog.load_default()
var _phase: int = -1
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


static func upgrade_label(upgrade: UpgradeData, level: int) -> String:
	if level >= upgrade.max_level:
		return "%s %d/%d (max)" % [upgrade.display_name, level, upgrade.max_level]
	return "%s %d/%d · %d" % [upgrade.display_name, level, upgrade.max_level, upgrade.cost(level)]


func _ready() -> void:
	hide()
	_build_buttons()
	EventBus.match_state_changed.connect(_on_match_state_changed)
	NetworkManager.session_ended.connect(func(_reason: String) -> void: _phase = -1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shop") and _shop_phase():
		_hidden_by_player = not _hidden_by_player
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var player: Player = Player.find_local(get_tree())
	visible = NetworkManager.is_online() and _shop_phase() and not _hidden_by_player
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
	var phase: int = (state as MatchNetState).phase
	if phase != _phase:
		_phase = phase
		_hidden_by_player = false


func _shop_phase() -> bool:
	return _phase == GameMode.Phase.LOBBY or _phase == GameMode.Phase.BREAK


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
		_upgrade_buttons[i].text = upgrade_label(_catalog.upgrades[i], level)
		var problem: String = ShopRules.check_upgrade(true, _catalog, i, level, credits)
		_upgrade_buttons[i].disabled = not problem.is_empty()
