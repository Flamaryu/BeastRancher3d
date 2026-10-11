class_name MonsterInstance
extends Resource

## Runtime state representing an individual monster.
## Tracks husbandry state, lineage/genetics, combat stats, economic valuation, and evolution growth.

const EventBusScript = preload("res://scripts/core/EventBus.gd")

@export_group("Identification")
@export var beast_id: String = ""
@export var nickname: String = ""
@export var base_species: SpeciesBlueprint = null
@export var current_species: SpeciesBlueprint = null
@export var stage: String = "juvenile" # "juvenile", "adult", "elder"
@export var age_days: int = 0

@export_group("Husbandry")
@export_range(0, 100) var temperament: int = 80
@export_range(0, 100) var hygiene: int = 80
@export_range(0, 100) var satiety: int = 80
@export var diet_history: Array[String] = []
@export var catalytic_points: Dictionary = {}

@export_group("Stats")
@export var current_atk: int = 10
@export var current_def: int = 10
@export var current_speed: int = 10
@export var current_max_hp: int = 100

@export_group("Genetics & Pedigree")
@export var pedigree_rank: String = "C" # F, E, D, C, B, A, S
@export_range(0.0, 1.0) var bloodline_purity: float = 1.0
@export var gene_slots: Array[String] = []

@export_group("Certification")
@export var certification_grade: String = "Standard" # "None", "Standard", "Elite", "Master"

## Initializes the monster from a species blueprint.
func initialize(species: SpeciesBlueprint, p_beast_id: String = "", p_nickname: String = "") -> void:
	base_species = species
	current_species = species
	beast_id = p_beast_id if not p_beast_id.is_empty() else str("beast_", randi() % 99999)
	nickname = p_nickname if not p_nickname.is_empty() else (species.species_name if species != null else "Unnamed Beast")
	stage = "juvenile"
	age_days = 0

	if species != null:
		current_atk = species.base_atk
		current_def = species.base_def
		current_speed = species.base_speed
		current_max_hp = species.base_max_hp

## Calculates economic market valuation reflecting species tier, pedigree, husbandry, traits, and certification.
func calculate_appraisal_value() -> int:
	if current_species == null:
		return 0

	# 1. Base Species Tier Value
	var tier_multiplier: float = 1.0 + float(maxi(1, current_species.tier) - 1) * 0.75
	var base_value: float = float(current_species.base_valuation) * tier_multiplier

	# 2. Pedigree Rank Multiplier (F to S)
	var pedigree_mult: float = 1.0
	match pedigree_rank.to_upper():
		"S": pedigree_mult = 3.0
		"A": pedigree_mult = 2.2
		"B": pedigree_mult = 1.6
		"C": pedigree_mult = 1.0
		"D": pedigree_mult = 0.7
		"E": pedigree_mult = 0.5
		"F": pedigree_mult = 0.3
		_: pedigree_mult = 1.0

	# 3. Bloodline Purity Factor (0.0 to 1.0 -> 0.6x to 1.4x)
	var purity_factor: float = 0.6 + (clampf(bloodline_purity, 0.0, 1.0) * 0.8)

	# 4. Husbandry State Factor (temperament, hygiene, satiety)
	var husbandry_avg: float = float(temperament + hygiene + satiety) / 300.0
	var husbandry_mult: float = 0.4 + (husbandry_avg * 0.9)

	# 5. Growth Stage Multiplier
	var stage_mult: float = 1.0
	match stage.to_lower():
		"juvenile": stage_mult = 0.75
		"adult": stage_mult = 1.35
		"elder": stage_mult = 1.10

	# 6. Certification Grade Multiplier
	var cert_mult: float = 1.0
	match certification_grade.to_lower():
		"none": cert_mult = 1.0
		"standard": cert_mult = 1.15
		"elite": cert_mult = 1.45
		"master": cert_mult = 1.90

	# 7. Combat / Stat Training Value
	var stat_total: int = current_atk + current_def + current_speed + int(float(current_max_hp) * 0.25)
	var stat_bonus: float = float(stat_total) * 1.5

	# 8. Gene Slot Bonuses (e.g., active hereditary traits)
	var gene_bonus: float = float(gene_slots.size()) * 75.0

	var final_value: float = (base_value * pedigree_mult * purity_factor * husbandry_mult * stage_mult * cert_mult) + stat_bonus + gene_bonus
	return maxi(1, int(round(final_value)))

## Feeds a crop to the monster, updating satiety, applying nutritional stat modifiers, and adding catalytic points.
func feed(crop: CropData) -> void:
	if crop == null:
		return

	satiety = clampi(satiety + crop.satiety_restoration, 0, 100)
	hygiene = clampi(hygiene + crop.hygiene_modifier, 0, 100)
	temperament = clampi(temperament + crop.temperament_modifier, 0, 100)

	current_atk = maxi(1, current_atk + crop.atk_modifier)
	current_def = maxi(1, current_def + crop.def_modifier)
	current_speed = maxi(1, current_speed + crop.speed_modifier)
	current_max_hp = maxi(10, current_max_hp + crop.max_hp_modifier)

	diet_history.append(crop.crop_id)

	# Accumulate evolution catalytic points from crop
	for cat_key in crop.evolution_catalytic_points.keys():
		var pts: int = int(crop.evolution_catalytic_points[cat_key])
		catalytic_points[cat_key] = int(catalytic_points.get(cat_key, 0)) + pts

	_notify_beast_fed(crop.crop_id)

	# Check for evolution opportunity
	if check_evolution_eligibility():
		evolve()

## Processes daily tick: decays satiety/hygiene, adjusts temperament, and checks evolution eligibility.
func process_daily_tick() -> void:
	age_days += 1

	# Daily metabolism decay
	satiety = clampi(satiety - 15, 0, 100)
	hygiene = clampi(hygiene - 10, 0, 100)

	# Husbandry neglect degrades temperament; high health sustains happiness
	if satiety < 25:
		temperament = clampi(temperament - 12, 0, 100)
	elif satiety < 50:
		temperament = clampi(temperament - 5, 0, 100)

	if hygiene < 25:
		temperament = clampi(temperament - 8, 0, 100)

	if satiety >= 70 and hygiene >= 70:
		temperament = clampi(temperament + 5, 0, 100)

	# Juvenile natural conditioning
	if stage.to_lower() == "juvenile":
		current_max_hp += 2

	# Check for evolution opportunity
	if check_evolution_eligibility():
		evolve()

## Evaluates whether the beast meets all criteria for evolution into its target species.
func check_evolution_eligibility() -> bool:
	if current_species == null:
		return false

	var target_spec: SpeciesBlueprint = current_species.evolves_to_species
	if target_spec == null and current_species.evolves_to_species_id.is_empty():
		return false

	# Age requirement
	if age_days < current_species.min_evolution_days:
		return false

	# Husbandry thresholds
	if temperament < current_species.min_temperament or satiety < current_species.min_satiety:
		return false

	# Combat stat thresholds
	if current_atk < current_species.min_atk or current_def < current_species.min_def:
		return false

	# Catalytic points verification
	for cat_key in current_species.required_catalytic_points.keys():
		var required_pts: int = int(current_species.required_catalytic_points[cat_key])
		var current_pts: int = int(catalytic_points.get(cat_key, 0))
		if current_pts < required_pts:
			return false

	# Diet crops requirements
	for required_crop in current_species.required_diet_crops:
		if not diet_history.has(required_crop):
			return false

	return true

## Executes the evolution transformation to the target species blueprint.
func evolve(target_species: SpeciesBlueprint = null) -> bool:
	var new_species: SpeciesBlueprint = target_species
	if new_species == null and current_species != null:
		new_species = current_species.evolves_to_species

	if new_species == null:
		return false

	var previous_species: SpeciesBlueprint = current_species
	current_species = new_species
	stage = "adult"

	# Apply evolutionary stat bonuses based on species blueprint delta
	if previous_species != null:
		current_atk += maxi(0, new_species.base_atk - previous_species.base_atk)
		current_def += maxi(0, new_species.base_def - previous_species.base_def)
		current_speed += maxi(0, new_species.base_speed - previous_species.base_speed)
		current_max_hp += maxi(0, new_species.base_max_hp - previous_species.base_max_hp)
	else:
		current_atk = new_species.base_atk
		current_def = new_species.base_def
		current_speed = new_species.base_speed
		current_max_hp = new_species.base_max_hp

	# Evolution joy bonus
	temperament = clampi(temperament + 15, 0, 100)

	_notify_beast_evolved(new_species.species_id)
	return true

func _notify_beast_fed(crop_id: String) -> void:
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("beast_fed"):
		bus.beast_fed.emit(beast_id, crop_id)

func _notify_beast_evolved(new_species_id: String) -> void:
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("beast_evolved"):
		bus.beast_evolved.emit(beast_id, new_species_id)

func _get_event_bus() -> Node:
	if is_instance_valid(EventBusScript.instance):
		return EventBusScript.instance
	return null
