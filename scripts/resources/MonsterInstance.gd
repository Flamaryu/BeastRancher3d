class_name MonsterInstance
extends Resource

## Runtime state representing an individual monster.
## Tracks husbandry state, lineage/genetics, combat stats, economic valuation,
## and variable-form evolution progression across 2 or 3 forms.

const EventBusScript = preload("res://scripts/core/EventBus.gd")
const SpeciesData = preload("res://scripts/resources/SpeciesData.gd")

@export_group("Identification")
@export var beast_id: String = ""
@export var nickname: String = ""
@export var base_species: SpeciesBlueprint = null
@export var current_species: SpeciesBlueprint = null
@export var stage: String = "juvenile" # "juvenile", "adult", "elder"
@export var age_days: int = 0

@export_group("Phase 3 Variable Forms & Variants")
@export var species_data: SpeciesData = null
@export var current_form_index: int = 0
@export var color_variant_index: int = 0
@export var appraisal_value: int = 0

## Alias for age_days to support requirements referring to days_old.
var days_old: int:
	get:
		return age_days
	set(value):
		age_days = value

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

## Initializes the monster from a species blueprint (Phase 1/2 legacy).
func initialize(species: SpeciesBlueprint, p_beast_id: String = "", p_nickname: String = "") -> void:
	base_species = species
	current_species = species
	species_data = null
	current_form_index = 0
	color_variant_index = 0
	beast_id = p_beast_id if not p_beast_id.is_empty() else str("beast_", randi() % 99999)
	nickname = p_nickname if not p_nickname.is_empty() else (species.species_name if species != null else "Unnamed Beast")
	stage = "juvenile"
	age_days = 0

	if species != null:
		current_atk = species.base_atk
		current_def = species.base_def
		current_speed = species.base_speed
		current_max_hp = species.base_max_hp
	appraisal_value = calculate_appraisal_value()

## Initializes the monster from a Phase 3 SpeciesData resource.
func initialize_species_data(species: SpeciesData, p_beast_id: String = "", p_nickname: String = "") -> void:
	species_data = species
	base_species = null
	current_species = null
	current_form_index = 0
	color_variant_index = 0
	beast_id = p_beast_id if not p_beast_id.is_empty() else str("beast_", randi() % 99999)
	nickname = p_nickname if not p_nickname.is_empty() else (species.display_name if species != null else "Unnamed Beast")
	stage = "juvenile"
	age_days = 0
	current_atk = 10
	current_def = 10
	current_speed = 10
	current_max_hp = 100
	if species != null:
		appraisal_value = int(round(float(species.base_value) * species.get_form_multiplier(0)))
	else:
		appraisal_value = 0

## Calculates economic market valuation reflecting species tier, pedigree, husbandry, traits, and certification.
## Phase 4A Unified Appraisal Formula:
## Final Sale Value = ((Base Value * Form Multiplier * Pedigree Multiplier) + Trait Value Sum) * (1.0 + Husbandry Bonus) * Certification Multiplier
func calculate_appraisal_value() -> int:
	if species_data != null:
		var base_val: float = float(species_data.base_value)
		var form_mult: float = species_data.get_form_multiplier(current_form_index)

		# Pedigree Rank Multiplier (F to S)
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

		# Trait Value Sum ("Berserk_Rush" = 300, standard traits = 75)
		var trait_sum: float = 0.0
		for gene in gene_slots:
			if gene == "Berserk_Rush":
				trait_sum += 300.0
			else:
				trait_sum += 75.0

		# Husbandry Bonus (based on average satiety, hygiene, temperament)
		var husbandry_avg: float = float(temperament + hygiene + satiety) / 300.0
		var husbandry_bonus: float = husbandry_avg * 0.20

		# Certification Multiplier
		var cert_mult: float = 1.0
		match certification_grade.to_lower():
			"gold", "master": cert_mult = 2.00
			"silver", "elite": cert_mult = 1.50
			"bronze", "standard": cert_mult = 1.25
			_: cert_mult = 1.00

		var base_product: float = base_val * form_mult * pedigree_mult
		var subtotal: float = base_product + trait_sum
		var final_value: float = subtotal * (1.0 + husbandry_bonus) * cert_mult
		appraisal_value = maxi(1, int(round(final_value)))
		return appraisal_value

	if current_species == null:
		return 0

	# 1. Base Species Tier Value
	var tier_multiplier: float = 1.0 + float(maxi(1, current_species.tier) - 1) * 0.75
	var base_val: float = float(current_species.base_valuation) * tier_multiplier

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

	var final_value: float = (base_val * pedigree_mult * purity_factor * husbandry_mult * stage_mult * cert_mult) + stat_bonus + gene_bonus
	appraisal_value = maxi(1, int(round(final_value)))
	return appraisal_value

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
		if species_data != null:
			evolve_to_next_form()
		else:
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
		if species_data != null:
			evolve_to_next_form()
		else:
			evolve()

## Evaluates whether the beast meets all criteria for evolution into its next form or species.
func check_evolution_eligibility() -> bool:
	if species_data != null:
		# Check if already at maximum form for this species (e.g. index 1 for 2 forms or index 2 for 3 forms)
		if current_form_index >= species_data.get_max_form_index():
			return false

		var target_idx: int = current_form_index + 1
		var req: Dictionary = species_data.get_evolution_requirement(target_idx)
		if not req.is_empty():
			var min_days: int = req.get("min_days", req.get("min_evolution_days", 0))
			if days_old < min_days:
				return false

			var min_diet: int = req.get("min_diet_count", 0)
			if diet_history.size() < min_diet:
				return false

			var req_cat: Dictionary = req.get("required_catalytic", req.get("required_diet_points", {}))
			for cat_key in req_cat.keys():
				var req_pts: int = int(req_cat[cat_key])
				var cur_pts: int = int(catalytic_points.get(cat_key, 0))
				if cur_pts < req_pts:
					return false

			var req_crops: Array = req.get("required_crops", req.get("required_diet_crops", []))
			for c in req_crops:
				if not diet_history.has(str(c)):
					return false
		else:
			# Default progression requirements if no explicit dictionary is provided
			var def_days: int = 3 if target_idx == 1 else 6
			if days_old < def_days:
				return false

		return true

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

## Executes Phase 3 variable-form evolution progression to current_form_index + 1.
func evolve_to_next_form() -> bool:
	if species_data == null:
		return false
	if current_form_index >= species_data.get_max_form_index():
		return false

	current_form_index += 1

	# Evaluate color variant unlocked by diet & catalytic points
	_evaluate_color_variant_unlock()

	# Update life stage
	if current_form_index >= species_data.get_max_form_index():
		stage = "elder"
	else:
		stage = "adult"

	# Apply stat scaling per evolution form
	current_atk = int(round(float(current_atk) * 1.3))
	current_def = int(round(float(current_def) * 1.3))
	current_speed = int(round(float(current_speed) * 1.2))
	current_max_hp = int(round(float(current_max_hp) * 1.4))
	temperament = clampi(temperament + 15, 0, 100)

	# Update appraisal value using form multiplier
	var mult: float = species_data.get_form_multiplier(current_form_index)
	appraisal_value = int(round(float(species_data.base_value) * mult))

	# Notify via EventBus
	_notify_beast_evolved_form(current_form_index, color_variant_index)
	return true

## Executes the Phase 1/2 evolution transformation to the target species blueprint.
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

func _evaluate_color_variant_unlock() -> void:
	# Index 0: Standard, Index 1: Elemental Shift, Index 2: Rare Mutation
	var mut_thresh: int = 15
	var elem_thresh: int = 10
	if species_data != null and not species_data.variant_thresholds.is_empty():
		var mut_cfg: Dictionary = species_data.variant_thresholds.get(2, species_data.variant_thresholds.get("2", {}))
		if not mut_cfg.is_empty():
			mut_thresh = int(mut_cfg.values()[0])
		var elem_cfg: Dictionary = species_data.variant_thresholds.get(1, species_data.variant_thresholds.get("1", {}))
		if not elem_cfg.is_empty():
			elem_thresh = int(elem_cfg.values()[0])

	var mutation_pts: int = int(catalytic_points.get("mutation", 0)) + int(catalytic_points.get("cosmic", 0)) + int(catalytic_points.get("aberrant", 0))
	for diet_item in diet_history:
		var l_diet: String = diet_item.to_lower()
		if "mutation" in l_diet or "cosmic" in l_diet:
			mutation_pts += 10

	var elemental_pts: int = int(catalytic_points.get("fire", 0)) + int(catalytic_points.get("sun", 0)) + int(catalytic_points.get("water", 0)) + int(catalytic_points.get("earth", 0)) + int(catalytic_points.get("elemental", 0))
	for diet_item in diet_history:
		var l_diet: String = diet_item.to_lower()
		if "elemental" in l_diet or "sun" in l_diet or "fire" in l_diet or "water" in l_diet or "earth" in l_diet:
			elemental_pts += 5

	if mutation_pts >= mut_thresh:
		color_variant_index = 2
	elif elemental_pts >= elem_thresh:
		color_variant_index = maxi(color_variant_index, 1)
	else:
		color_variant_index = maxi(color_variant_index, 0)

func _notify_beast_fed(crop_id: String) -> void:
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("beast_fed"):
		bus.beast_fed.emit(beast_id, crop_id)

func _notify_beast_evolved_form(form_idx: int, variant_idx: int) -> void:
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("beast_evolved"):
		bus.beast_evolved.emit(beast_id, form_idx, variant_idx)

func _notify_beast_evolved(new_species_id: String) -> void:
	var bus: Node = _get_event_bus()
	if bus != null and bus.has_signal("beast_evolved"):
		bus.beast_evolved.emit(beast_id, new_species_id, 0)

func _get_event_bus() -> Node:
	if is_instance_valid(EventBusScript.instance):
		return EventBusScript.instance
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null and tree.root.has_node("EventBus"):
		return tree.root.get_node("EventBus")
	return null
