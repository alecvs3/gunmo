class_name PetPanel
extends HudMenu
## The Pets menu (P, Waves). On the left the three pets; on the right the chosen pet's five-tier
## ladder and one big button that adopts it or buys its next tier. Opening, closing and the look
## of the window come from HudMenu.
## Buying only *asks* (EventBus.shop_purchase_requested with ShopRules.KIND_PET); the host checks
## and applies. Your pet, tier and credits come from your own player's replicated state, so a
## tier lights up only once the host has confirmed it.

var _pets: PetCatalog = PetCatalog.load_default()
var _selected: int = 0
var _last_owned: Vector2i = Vector2i(-2, 0)
var _cards: Array[PetCard] = []
var _rows: Array[PetTierRow] = []
var _credits := Label.new()
var _portrait := PetPortrait.new()
var _name := Label.new()
var _role := Label.new()
var _blurb := Label.new()
var _buy := Button.new()
var _warning := Label.new()


## The big button: adopt the pet, buy its next tier, or nothing left to buy.
static func buy_text(pet: PetData, owned: int) -> String:
	if owned >= pet.tiers.size():
		return "%s is at its highest tier" % pet.display_name
	if owned == 0:
		return "Adopt %s · %d" % [pet.display_name, pet.tiers[0].price]
	var tier: PetTier = pet.tiers[owned]
	return "Tier %d: %s · %d" % [owned + 1, tier.display_name, tier.price]


## Said before you swap pets ("" when you have none, or are looking at your own).
static func switch_warning(current: PetData, tier: int, chosen: PetData) -> String:
	if current == null or current == chosen:
		return ""
	return (
		"Adopting %s leaves your %s (tier %d) behind: its tiers are lost."
		% [chosen.display_name, current.display_name, tier]
	)


func _action() -> StringName:
	return &"pets"


func _hint_text() -> String:
	return "P: Pets"


func _hint_slot() -> int:
	return 1


## Opens on your own pet, if you have one.
func _on_opened(player: Player) -> void:
	if player != null and player.get_loadout().pet_index >= 0:
		_selected = player.get_loadout().pet_index


func _build_content(into: PanelContainer) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	into.add_child(column)
	column.add_child(_build_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	column.add_child(body)
	body.add_child(_build_list())
	body.add_child(_build_detail())
	column.add_child(label("P or Esc to close · the host confirms every purchase", 12, MUTED))
	_show_detail(_pets.pet(0), 0, false)
	for card in _cards:
		card.show_state(0, card.pet == _pets.pet(0))


func _select(index: int) -> void:
	_selected = index
	_sound.play(_sounds.click)


func _buy_pressed() -> void:
	_sound.play(_sounds.click)
	EventBus.shop_purchase_requested.emit(ShopRules.KIND_PET, _selected)


func _refresh(player: Player) -> void:
	var loadout: PlayerLoadout = player.get_loadout()
	var credits: int = player.get_wallet().credits
	_credits.text = "%d credits" % credits
	for i in _cards.size():
		var owned: int = loadout.pet_tier if i == loadout.pet_index else 0
		_cards[i].show_state(owned, i == _selected)
	var pet: PetData = _pets.pet(_selected)
	var owned_here: int = loadout.pet_tier if _selected == loadout.pet_index else 0
	var problem: String = ShopRules.check_pet(
		true, _pets, _selected, loadout.pet_index, loadout.pet_tier, credits
	)
	_show_detail(pet, owned_here, problem.is_empty())
	_warning.text = switch_warning(loadout.pet(), loadout.pet_tier, pet)
	_warning.visible = not _warning.text.is_empty()
	_pop_if_bought(loadout)


## The right-hand side: the pet, its ladder and the buy button.
func _show_detail(pet: PetData, owned: int, can_buy: bool) -> void:
	_portrait.pet = pet
	_portrait.tier = owned
	_name.text = pet.display_name
	_role.text = pet.role
	_role.add_theme_color_override("font_color", pet.color)
	_blurb.text = pet.blurb
	for i in _rows.size():
		_rows[i].show_tier(pet, i, owned)
	_buy.text = buy_text(pet, owned)
	_buy.disabled = not can_buy


## A tier the host confirmed since the last refresh: its row flashes and the bought sound plays.
func _pop_if_bought(loadout: PlayerLoadout) -> void:
	var now := Vector2i(loadout.pet_index, loadout.pet_tier)
	var grew: bool = now.x == _last_owned.x and now.y > _last_owned.y
	var adopted: bool = _last_owned.x != -2 and now.x != _last_owned.x and now.x >= 0
	if (grew or adopted) and now.x == _selected and now.y > 0:
		_rows[now.y - 1].pop()
		_sound.play(_sounds.bought)
	_last_owned = now


func _build_header() -> Control:
	var header := HBoxContainer.new()
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(label("Pets", 24, Color.WHITE))
	titles.add_child(
		label("One pet each. Every tier adds an ability and strengthens the last.", 13, MUTED)
	)
	_credits.add_theme_color_override("font_color", GOLD)
	_credits.add_theme_font_size_override("font_size", 20)
	header.add_child(_credits)
	return header


func _build_list() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(206, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	for i in _pets.pets.size():
		var card := PetCard.new(_pets.pets[i])
		card.pressed.connect(_select.bind(i))
		list.add_child(card)
		_cards.append(card)
	return scroll


func _build_detail() -> Control:
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	detail.add_child(top)
	_portrait.custom_minimum_size = Vector2(96, 96)
	top.add_child(_portrait)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(words)
	_name.add_theme_font_size_override("font_size", 22)
	words.add_child(_name)
	words.add_child(_role)
	_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_blurb.add_theme_color_override("font_color", MUTED)
	words.add_child(_blurb)
	detail.add_child(_build_ladder())
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.hide()
	_warning.add_theme_color_override("font_color", Color(1, 0.55, 0.45))
	detail.add_child(_warning)
	_buy.custom_minimum_size = Vector2(0, 40)
	_buy.add_theme_font_size_override("font_size", 17)
	_buy.add_theme_stylebox_override("normal", box(Color(GOLD, 0.22), GOLD, 2))
	_buy.add_theme_stylebox_override("hover", box(Color(GOLD, 0.34), GOLD, 2))
	_buy.add_theme_stylebox_override("disabled", box(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.1)))
	_buy.pressed.connect(_buy_pressed)
	detail.add_child(_buy)
	return detail


func _build_ladder() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var ladder := VBoxContainer.new()
	ladder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ladder.add_theme_constant_override("separation", 6)
	scroll.add_child(ladder)
	for i in PetData.TIERS:
		var row := PetTierRow.new()
		ladder.add_child(row)
		_rows.append(row)
	return scroll
