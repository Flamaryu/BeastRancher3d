class_name RanchHUD
extends Control

## Touch-friendly Mobile Ranch HUD managing creature inspection drawer,
## real-time husbandry meters (Satiety, Hygiene, Temperament), and the Feed Action Bar.

const EventBusScript = preload("res://scripts/core/EventBus.gd")
const CropDataScript = preload("res://scripts/resources/CropData.gd")

@export var sample_crops: Array[CropData] = []

@onready var inspect_drawer: PanelContainer = get_node_or_null("InspectDrawer")
@onready var nickname_label: Label = get_node_or_null("InspectDrawer/VBox/Header/TitleBox/TitleLabel")
@onready var species_info_label: Label = get_node_or_null("InspectDrawer/VBox/Header/TitleBox/SubtitleLabel")
@onready var appraisal_label: Label = get_node_or_null("InspectDrawer/VBox/AppraisalLabel")
@onready var satiety_bar: ProgressBar = get_node_or_null("InspectDrawer/VBox/Meters/SatietyRow/SatietyBar")
@onready var satiety_label: Label = get_node_or_null("InspectDrawer/VBox/Meters/SatietyRow/SatietyValue")
@onready var hygiene_bar: ProgressBar = get_node_or_null("InspectDrawer/VBox/Meters/HygieneRow/HygieneBar")
@onready var hygiene_label: Label = get_node_or_null("InspectDrawer/VBox/Meters/HygieneRow/HygieneValue")
@onready var temperament_bar: ProgressBar = get_node_or_null("InspectDrawer/VBox/Meters/TemperamentRow/TemperamentBar")
@onready var temperament_label: Label = get_node_or_null("InspectDrawer/VBox/Meters/TemperamentRow/TemperamentValue")
@onready var feed_button_container: HBoxContainer = get_node_or_null("InspectDrawer/VBox/FeedSection/FeedButtonsContainer")
@onready var close_button: Button = get_node_or_null("InspectDrawer/VBox/Header/CloseButton")

var selected_monster: MonsterInstance = null
var drawer_tween: Tween = null
var meter_tween: Tween = null

func _enter_tree() -> void:
	_ensure_nodes()
	_connect_events()

func _ready() -> void:
	_ensure_nodes()
	_init_sample_crops()
	_populate_feed_action_bar()
	_connect_events()

	if close_button != null and not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

	if inspect_drawer != null:
		inspect_drawer.visible = false
		inspect_drawer.modulate.a = 0.0

func _ensure_nodes() -> void:
	if inspect_drawer == null:
		inspect_drawer = get_node_or_null("InspectDrawer")
	if nickname_label == null:
		nickname_label = get_node_or_null("InspectDrawer/VBox/Header/TitleBox/TitleLabel")
	if species_info_label == null:
		species_info_label = get_node_or_null("InspectDrawer/VBox/Header/TitleBox/SubtitleLabel")
	if appraisal_label == null:
		appraisal_label = get_node_or_null("InspectDrawer/VBox/AppraisalLabel")
	if satiety_bar == null:
		satiety_bar = get_node_or_null("InspectDrawer/VBox/Meters/SatietyRow/SatietyBar")
	if satiety_label == null:
		satiety_label = get_node_or_null("InspectDrawer/VBox/Meters/SatietyRow/SatietyValue")
	if hygiene_bar == null:
		hygiene_bar = get_node_or_null("InspectDrawer/VBox/Meters/HygieneRow/HygieneBar")
	if hygiene_label == null:
		hygiene_label = get_node_or_null("InspectDrawer/VBox/Meters/HygieneRow/HygieneValue")
	if temperament_bar == null:
		temperament_bar = get_node_or_null("InspectDrawer/VBox/Meters/TemperamentRow/TemperamentBar")
	if temperament_label == null:
		temperament_label = get_node_or_null("InspectDrawer/VBox/Meters/TemperamentRow/TemperamentValue")
	if feed_button_container == null:
		feed_button_container = get_node_or_null("InspectDrawer/VBox/FeedSection/FeedButtonsContainer")
	if close_button == null:
		close_button = get_node_or_null("InspectDrawer/VBox/Header/CloseButton")

func _init_sample_crops() -> void:
	if not sample_crops.is_empty():
		return

	# Default sample crops for testing
	var pepper: CropData = CropDataScript.new()
	pepper.crop_id = "sunburst_pepper"
	pepper.display_name = "Sunburst Pepper"
	pepper.atk_modifier = 3
	pepper.satiety_restoration = 35
	pepper.temperament_modifier = 8
	pepper.evolution_catalytic_points = {"fire": 5}
	sample_crops.append(pepper)

	var grass: CropData = CropDataScript.new()
	grass.crop_id = "iron_grass"
	grass.display_name = "Iron Grass"
	grass.def_modifier = 4
	grass.satiety_restoration = 25
	grass.temperament_modifier = 5
	grass.evolution_catalytic_points = {"earth": 5}
	sample_crops.append(grass)

	var melon: CropData = CropDataScript.new()
	melon.crop_id = "flame_melon"
	melon.display_name = "Flame Melon"
	melon.atk_modifier = 2
	melon.speed_modifier = 2
	melon.satiety_restoration = 30
	melon.temperament_modifier = 10
	melon.evolution_catalytic_points = {"fire": 5}
	sample_crops.append(melon)

func _populate_feed_action_bar() -> void:
	_ensure_nodes()
	if feed_button_container == null:
		return

	for child in feed_button_container.get_children():
		child.queue_free()

	for crop in sample_crops:
		var btn: Button = Button.new()
		btn.text = "Feed %s" % crop.display_name
		btn.custom_minimum_size = Vector2(160, 48)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): _on_feed_button_pressed(crop))
		feed_button_container.add_child(btn)

func _connect_events() -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return

	if bus.has_signal("monster_selected") and not bus.monster_selected.is_connected(_on_monster_selected):
		bus.monster_selected.connect(_on_monster_selected)
	if bus.has_signal("monster_deselected") and not bus.monster_deselected.is_connected(_on_monster_deselected):
		bus.monster_deselected.connect(_on_monster_deselected)
	if bus.has_signal("beast_fed") and not bus.beast_fed.is_connected(_on_beast_fed):
		bus.beast_fed.connect(_on_beast_fed)
	if bus.has_signal("beast_evolved") and not bus.beast_evolved.is_connected(_on_beast_evolved):
		bus.beast_evolved.connect(_on_beast_evolved)
	if bus.has_signal("hour_ticked") and not bus.hour_ticked.is_connected(_on_hour_ticked):
		bus.hour_ticked.connect(_on_hour_ticked)

func _on_monster_selected(monster: MonsterInstance) -> void:
	_ensure_nodes()
	selected_monster = monster
	_update_hud_display(false)
	_animate_drawer(true)

func _on_monster_deselected() -> void:
	selected_monster = null
	_animate_drawer(false)

func _on_close_button_pressed() -> void:
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("monster_deselected"):
		bus.monster_deselected.emit()
	else:
		_on_monster_deselected()

func _on_feed_button_pressed(crop: CropData) -> void:
	if selected_monster == null or crop == null:
		return

	# Execute feeding logic
	selected_monster.feed(crop)
	_update_hud_display(true)

func _on_beast_fed(beast_id: String, _crop_id: String) -> void:
	if selected_monster != null and selected_monster.beast_id == beast_id:
		_update_hud_display(true)

func _on_beast_evolved(beast_id: String, _new_species_id: Variant = null, _variant: int = 0) -> void:
	if selected_monster != null and selected_monster.beast_id == beast_id:
		_update_hud_display(true)

func _on_hour_ticked(_hour: int) -> void:
	if selected_monster != null:
		_update_hud_display(true)

func _update_hud_display(animate_meters: bool) -> void:
	if selected_monster == null:
		return

	_ensure_nodes()

	# Header text
	if nickname_label != null:
		nickname_label.text = "%s" % selected_monster.nickname
	if species_info_label != null:
		var species_name: String = selected_monster.current_species.species_name if selected_monster.current_species != null else "Unknown"
		species_info_label.text = "%s • Rank %s • %s" % [species_name, selected_monster.pedigree_rank, selected_monster.stage.capitalize()]

	# Appraisal
	var value: int = selected_monster.calculate_appraisal_value()
	if appraisal_label != null:
		appraisal_label.text = "Valuation: %d Gold" % value

	# Husbandry meters
	var target_satiety: float = float(selected_monster.satiety)
	var target_hygiene: float = float(selected_monster.hygiene)
	var target_temp: float = float(selected_monster.temperament)

	if satiety_label != null:
		satiety_label.text = "%d / 100" % int(target_satiety)
	if hygiene_label != null:
		hygiene_label.text = "%d / 100" % int(target_hygiene)
	if temperament_label != null:
		temperament_label.text = "%d / 100" % int(target_temp)

	if animate_meters and is_inside_tree():
		if meter_tween != null and meter_tween.is_valid():
			meter_tween.kill()
		meter_tween = create_tween().set_parallel(true)
		if satiety_bar != null:
			meter_tween.tween_property(satiety_bar, "value", target_satiety, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if hygiene_bar != null:
			meter_tween.tween_property(hygiene_bar, "value", target_hygiene, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if temperament_bar != null:
			meter_tween.tween_property(temperament_bar, "value", target_temp, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		if satiety_bar != null:
			satiety_bar.value = target_satiety
		if hygiene_bar != null:
			hygiene_bar.value = target_hygiene
		if temperament_bar != null:
			temperament_bar.value = target_temp

func _animate_drawer(show_drawer: bool) -> void:
	_ensure_nodes()
	if inspect_drawer == null:
		return

	if not is_inside_tree():
		inspect_drawer.visible = show_drawer
		return

	if drawer_tween != null and drawer_tween.is_valid():
		drawer_tween.kill()

	drawer_tween = create_tween().set_parallel(true)

	if show_drawer:
		inspect_drawer.visible = true
		drawer_tween.tween_property(inspect_drawer, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		drawer_tween.tween_property(inspect_drawer, "position:y", size.y - inspect_drawer.size.y - 16.0, 0.25).from(size.y + 20.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		drawer_tween.tween_property(inspect_drawer, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		drawer_tween.tween_property(inspect_drawer, "position:y", size.y + 20.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		drawer_tween.chain().tween_callback(func(): if inspect_drawer != null: inspect_drawer.visible = false)

func _get_event_bus() -> Node:
	if is_instance_valid(EventBusScript.instance):
		return EventBusScript.instance
	if is_inside_tree() and has_node("/root/EventBus"):
		return get_node("/root/EventBus")
	return null
