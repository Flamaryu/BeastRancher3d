class_name TestRanchController
extends Node3D

## Controller for the Phase 2 Ranch Scene.
## Initializes the discrete GridManager, Pen3D, test MonsterInstance, and hooks up the MonsterEntity and RanchHUD.

const SpeciesBlueprintScript = preload("res://scripts/resources/SpeciesBlueprint.gd")
const MonsterInstanceScript = preload("res://scripts/resources/MonsterInstance.gd")
const EventBusScript = preload("res://scripts/core/EventBus.gd")

@onready var pen: Pen3D = $Pen3D
@onready var monster_entity: MonsterEntity = $MonsterEntity
@onready var hud: RanchHUD = $HUDCanvas/RanchHUD
@onready var touch_manager: TouchInputManager = $TouchInputManager

func _ready() -> void:
	_setup_test_creature()

func _setup_test_creature() -> void:
	# Define a species blueprint
	var species: SpeciesBlueprint = SpeciesBlueprintScript.new()
	species.species_id = "burrow_pup"
	species.species_name = "Ember Burrow"
	species.tier = 1
	species.element_type = "Fire"
	species.base_atk = 14
	species.base_def = 10
	species.base_speed = 12
	species.base_max_hp = 100
	species.model_path = "res://assets/models/Free Burrow Cute Series/FBX/Burrow@Walk Forward In Place.FBX"

	# Create runtime monster data
	var monster_data: MonsterInstance = MonsterInstanceScript.new()
	monster_data.initialize(species, "beast_burrow_01", "Barnaby")
	monster_data.pedigree_rank = "A"
	monster_data.bloodline_purity = 0.92
	monster_data.stage = "juvenile"
	monster_data.satiety = 45 # Hungry so feeding is immediately noticeable
	monster_data.hygiene = 70
	monster_data.temperament = 65
	monster_data.gene_slots = ["Gene_WarmCoat", "Gene_DiggingPaw"]

	# Assign to Pen and MonsterEntity
	if pen != null:
		pen.assign_monster(monster_data)
		monster_entity.pen_reference = pen
		# Position monster at center of pen
		var pen_center: Vector3 = pen.get_center() if pen.has_method("get_center") else pen.get_pen_world_bounds().get_center()
		pen_center.y = 0.0
		monster_entity.global_position = pen_center

	if monster_entity != null:
		monster_entity.monster_data = monster_data

	# Select the monster by default so the inspector drawer opens immediately for evaluation
	call_deferred("_select_initial_monster", monster_data)

func _select_initial_monster(monster: MonsterInstance) -> void:
	var bus: Node = null
	if is_instance_valid(EventBusScript.instance):
		bus = EventBusScript.instance
	elif is_inside_tree() and has_node("/root/EventBus"):
		bus = get_node("/root/EventBus")
	if bus != null and bus.has_signal("monster_selected"):
		bus.monster_selected.emit(monster)
