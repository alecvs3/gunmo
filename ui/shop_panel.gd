class_name ShopPanel
extends Control
## The shop: a big see-through window over the game. While the match says the shop is open
## (Waves: the lobby and between waves) a "B: Shop" hint shows; B opens the window, B, Esc or a
## click outside closes it.
## Cards and buy buttons only *ask* to buy (EventBus.shop_purchase_requested); the host checks
## and applies. Credits, levels and the equipped weapon come from your own player's replicated
## state, so a card or level dot pops only once the host has confirmed the purchase.

const WEAPON_CARD: PackedScene = preload("res://ui/shop_weapon_card.tscn")
const UPGRADE_ROW: PackedScene = preload("res://ui/shop_upgrade_row.tscn")

var _catalog: ShopCatalog = ShopCatalog.load_default()
var _phase: int = -1
var _open: bool = false
var _shown_by_player: bool = false
var _cards: Array[ShopWeaponCard] = []
var _rows: Array[ShopUpgradeRow] = []
## What the last refresh showed (null = nothing yet, so opening the shop pops nothing).
var _seen: ShopSeen = null
var _sounds: SoundData = SoundData.load_default()
var _sound := SoundPlayback.new()

@onready var _hint: Label = %Hint
@onready var _dim: ColorRect = %Dim
@onready var _window: Control = %Window
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


func _ready() -> void:
	hide()
	add_child(_sound)
	_build()
	_dim.gui_input.connect(_on_dim_input)
	EventBus.match_state_changed.connect(_on_match_state_changed)
	NetworkManager.session_ended.connect(_on_session_ended.unbind(1))


## Esc closes the shop before the game menu (which reads Esc in _unhandled_input) sees it.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible and _shown_by_player:
		_show_window(false)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shop") and _open:
		_show_window(not _shown_by_player)
		get_viewport().set_input_as_handled()


## The player opened or closed the window (with its sound).
func _show_window(shown: bool) -> void:
	_shown_by_player = shown
	_sound.play(_sounds.shop_open if shown else _sounds.shop_close)


func _process(_delta: float) -> void:
	visible = NetworkManager.is_online() and _open
	_hint.visible = not _shown_by_player
	_dim.visible = _shown_by_player
	_window.visible = _shown_by_player
	var player: Player = Player.find_local(get_tree())
	if not _window.visible or player == null:
		_seen = null
		return
	_refresh(player)


func _build() -> void:
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


func _on_dim_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		_show_window(false)
		_dim.accept_event()


## A new lobby or break starts with the shop closed again (the hint shows).
func _on_match_state_changed(state: RefCounted) -> void:
	var match_state := state as MatchNetState
	_open = match_state.shop_open
	if match_state.phase != _phase:
		_phase = match_state.phase
		_shown_by_player = false


func _on_session_ended() -> void:
	_phase = -1
	_open = false
	_shown_by_player = false


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
