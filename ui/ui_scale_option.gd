class_name UiScaleOption
extends OptionButton
## "UI size" picker: shows GameSettings.ui_scale and changes it. Stays in step with the other
## menu's picker. Only menus and the HUD change size; the world view stays the same (FairView).

const NAMES: Array[String] = ["Small", "Normal", "Large", "Huge"]


func _ready() -> void:
	for i in WindowRules.UI_SCALES.size():
		add_item("UI size: %s" % NAMES[i], i)
	_show(GameSettings.ui_scale)
	item_selected.connect(
		func(index: int) -> void: GameSettings.set_ui_scale(WindowRules.UI_SCALES[index])
	)
	GameSettings.ui_scale_changed.connect(_show)


func _show(scale: float) -> void:
	select(maxi(WindowRules.UI_SCALES.find(WindowRules.clean_ui_scale(scale)), 0))
